// Keyboard layouts: the list to choose from, a preview of the keys, and the
// chosen layout applied to this application's own input.
//
// cage gives the installer one fixed layout and offers no way to change it.
// A password typed here must produce the same characters as on the installed
// system, so once a layout is chosen, key presses are translated again from
// their key codes with libxkbcommon, which Qt itself uses for the same job
// but does not expose. Dead keys and Compose are not handled.
#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

struct xkb_context;
struct xkb_keymap;
struct xkb_state;

class Keyboard : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Each layout: id (an XKB layout, with its variant in parentheses) and name.
    Q_PROPERTY(QVariantList layouts READ layouts CONSTANT)
    Q_PROPERTY(QString layout READ layout WRITE setLayout NOTIFY layoutChanged)
    // The unshifted characters of the four main rows of keys.
    Q_PROPERTY(QVariantList rows READ rows NOTIFY layoutChanged)
public:
    explicit Keyboard(QObject *parent = nullptr);
    ~Keyboard() override;

    QVariantList layouts() const { return m_layouts; }
    QString layout() const { return m_layout; }
    void setLayout(const QString &layout);
    QVariantList rows() const;
    Q_INVOKABLE QString name(const QString &layout) const;

    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void layoutChanged();

private:
    QVariantList m_layouts;
    QString m_layout = QStringLiteral("us"); // The layout of the installer medium.
    xkb_context *m_context = nullptr;
    xkb_keymap *m_keymap = nullptr;
    xkb_state *m_state = nullptr;
    bool m_translating = false; // Only after the user chose a layout.
    bool m_forwarding = false;
};
