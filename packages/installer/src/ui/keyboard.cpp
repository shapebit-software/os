#include "keyboard.h"

#include <QCoreApplication>
#include <QFile>
#include <QKeyEvent>
#include <QRegularExpression>

#include <xkbcommon/xkbcommon.h>

namespace {

// The names of all layouts and variants, from xkeyboard-config.
const QString layoutList = QStringLiteral("/usr/share/X11/xkb/rules/evdev.lst");

// XKB key codes are the kernel's plus 8. First and last key of each row:
// 1 to =, Q to ], A to ', Z to /.
constexpr int offset = 8;
constexpr int rowKeys[4][2] = {{2, 13}, {16, 27}, {30, 40}, {44, 53}};

} // namespace

Keyboard::Keyboard(QObject *parent) : QObject(parent), m_context(xkb_context_new(XKB_CONTEXT_NO_FLAGS))
{
    // "! layout" lines are "us  English (US)"; "! variant" lines are
    // "dvorak  us: English (Dvorak)".
    static const QRegularExpression line(QStringLiteral("^\\s+(\\S+)\\s+(?:(\\S+): )?(.+)$"));
    QFile file(layoutList);
    QString section;
    QList<QPair<QString, QString>> found; // name, id
    if (file.open(QIODevice::ReadOnly)) {
        while (!file.atEnd()) {
            const QString text = QString::fromUtf8(file.readLine()).trimmed().prepend(QLatin1Char(' '));
            const auto match = line.match(text);
            if (text.startsWith(QLatin1String(" !")))
                section = text.mid(2).trimmed();
            else if (match.hasMatch() && match.captured(1) == QLatin1String("custom"))
                continue; // A placeholder for a layout that users define themselves.
            else if (section == QLatin1String("layout") && match.hasMatch())
                found.append({match.captured(3), match.captured(1)});
            else if (section == QLatin1String("variant") && match.hasMatch())
                found.append({match.captured(3), QStringLiteral("%1(%2)").arg(match.captured(2), match.captured(1))});
        }
    }
    if (found.isEmpty())
        found.append({QStringLiteral("English (US)"), m_layout});
    std::sort(found.begin(), found.end(),
              [](const auto &a, const auto &b) { return a.first.localeAwareCompare(b.first) < 0; });
    for (const auto &[name, id] : std::as_const(found))
        m_layouts.append(QVariantMap{{QStringLiteral("id"), id}, {QStringLiteral("name"), name}});

    setLayout(m_layout);
    m_translating = false;
    qApp->installEventFilter(this);
}

Keyboard::~Keyboard()
{
    xkb_state_unref(m_state);
    xkb_keymap_unref(m_keymap);
    xkb_context_unref(m_context);
}

void Keyboard::setLayout(const QString &layout)
{
    const QByteArray name = layout.section(QLatin1Char('('), 0, 0).toUtf8();
    const QByteArray variant = layout.section(QLatin1Char('('), 1).remove(QLatin1Char(')')).toUtf8();
    const xkb_rule_names names{nullptr, nullptr, name.constData(), variant.constData(), nullptr};
    xkb_keymap *keymap = xkb_keymap_new_from_names(m_context, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (keymap == nullptr)
        return; // Unknown layout: the current one stays.
    xkb_state_unref(m_state);
    xkb_keymap_unref(m_keymap);
    m_keymap = keymap;
    m_state = xkb_state_new(keymap);
    m_layout = layout;
    m_translating = true;
    emit layoutChanged();
}

QVariantList Keyboard::rows() const
{
    QVariantList rows;
    for (const auto &[first, last] : rowKeys) {
        QStringList keys;
        for (int key = first; key <= last; ++key) {
            const xkb_keysym_t *symbols = nullptr;
            const int count = m_keymap == nullptr ? 0
                : xkb_keymap_key_get_syms_by_level(m_keymap, key + offset, 0, 0, &symbols);
            const char32_t character = count == 1 ? xkb_keysym_to_utf32(symbols[0]) : 0;
            // Letters are shown as they are printed on the keys.
            keys.append(character == 0 ? QString() : QString::fromUcs4(&character, 1).toUpper());
        }
        rows.append(QVariant(keys));
    }
    return rows;
}

QString Keyboard::name(const QString &layout) const
{
    for (const QVariant &entry : m_layouts) {
        if (entry.toMap().value(QStringLiteral("id")) == layout)
            return entry.toMap().value(QStringLiteral("name")).toString();
    }
    return layout;
}

bool Keyboard::eventFilter(QObject *watched, QEvent *event)
{
    if (!m_translating || m_forwarding || m_state == nullptr || !watched->isWindowType()
        || (event->type() != QEvent::KeyPress && event->type() != QEvent::KeyRelease))
        return false;
    const auto *key = static_cast<QKeyEvent *>(event);
    const xkb_keycode_t code = key->nativeScanCode();
    if (code < offset) // Not from a keyboard: nothing to translate.
        return false;

    const bool press = event->type() == QEvent::KeyPress;
    char buffer[16] = {};
    xkb_state_key_get_utf8(m_state, code, buffer, sizeof buffer);
    const xkb_keysym_t symbol = xkb_state_key_get_one_sym(m_state, code);
    if (!key->isAutoRepeat())
        xkb_state_update_key(m_state, code, press ? XKB_KEY_DOWN : XKB_KEY_UP);

    const QString text = QString::fromUtf8(buffer);
    // Keys without text, such as Backspace and the arrows, are the same in every layout.
    if (text.isEmpty() || !text.at(0).isPrint() || text == key->text())
        return false;
    // Shortcuts match on the key, which for a Latin letter is its capital.
    const char16_t character = text.size() == 1 ? text.at(0).toUpper().unicode() : 0;
    const int qtKey = character >= 0x20 && character <= 0x7e ? character : key->key();
    QKeyEvent translated(key->type(), qtKey, key->modifiers(), code, symbol, key->nativeModifiers(),
                         text, key->isAutoRepeat(), key->count());
    m_forwarding = true;
    QCoreApplication::sendEvent(watched, &translated);
    m_forwarding = false;
    return true;
}
