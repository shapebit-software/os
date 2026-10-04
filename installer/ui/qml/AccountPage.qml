// The first owner: the user who administers this machine.
import QtQuick
import QtQuick.Layouts

Step {
    id: page

    readonly property string realName: (firstName.text.trim() + " " + lastName.text.trim()).trim()
    readonly property alias userName: userNameField.text
    readonly property alias password: passwordField.text
    readonly property int minimumLength: 8
    // 0 to 3: too short, then by length and by the kinds of characters.
    readonly property int strength: {
        const text = passwordField.text
        if (text.length < minimumLength)
            return 0
        const kinds = [/[a-z]/, /[A-Z]/, /[0-9]/, /[^A-Za-z0-9]/].filter(kind => kind.test(text)).length
        return text.length >= 14 && kinds >= 3 ? 3 : text.length >= 11 || kinds >= 3 ? 2 : 1
    }
    property bool userNameEdited: false
    property bool advanced: false

    // "Zoë" becomes "zoe": letters lose their accents, the rest is dropped.
    function suggestUserName(name) {
        return name.toLowerCase().normalize("NFD").replace(/[^a-z0-9]/g, "").replace(/^[0-9]+/, "").slice(0, 31)
    }

    number: 5
    label: qsTr("Account")
    heading: qsTr("Create your account")
    subtitle: qsTr("You’ll use this account to sign in to ShapeBit.")
    contentWidth: 386
    nextEnabled: firstName.text.trim() !== "" && userNameField.acceptableInput
        && passwordField.text.length >= minimumLength && passwordField.text === confirmField.text

    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Field {
            id: firstName
            objectName: "firstName"
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("First name")
            maximumLength: 49
            initialFocus: true
            onTextChanged: if (!page.userNameEdited) userNameField.text = page.suggestUserName(text)
        }
        Field {
            id: lastName
            objectName: "lastName"
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: qsTr("Last name")
            maximumLength: 50
        }
    }

    Field {
        id: passwordField
        objectName: "password"
        Layout.fillWidth: true
        label: qsTr("Password")
        echoMode: TextInput.Password
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: -6
        spacing: 4
        Repeater {
            model: 3
            Rectangle {
                required property int index
                Layout.fillWidth: true
                implicitHeight: 3
                color: page.strength > index ? (page.strength === 1 ? Theme.danger : Theme.accent) : Theme.track
            }
        }
    }
    Text {
        Layout.topMargin: -6
        text: [qsTr("At least %1 characters").arg(page.minimumLength), qsTr("Weak: easy to guess"),
               qsTr("Good"), qsTr("Strong")][page.strength]
        color: Theme.faint
        font.pixelSize: 10
    }

    Field {
        id: confirmField
        objectName: "confirm"
        Layout.fillWidth: true
        label: qsTr("Confirm password")
        echoMode: TextInput.Password
    }
    Text {
        Layout.topMargin: -6
        visible: confirmField.text !== "" && confirmField.text !== passwordField.text
        text: qsTr("The passwords are different.")
        color: Theme.danger
        font.pixelSize: 10
    }

    LinkButton {
        objectName: "advanced"
        text: qsTr("Advanced")
        onClicked: page.advanced = !page.advanced
    }
    Field {
        id: userNameField
        objectName: "userName"
        Layout.fillWidth: true
        // Also shown when a name gives no usable suggestion, so that the user can fix it.
        visible: page.advanced || (firstName.text.trim() !== "" && !acceptableInput)
        label: qsTr("User name")
        // Lowercase only, so the validator does not reject what the keyboard suggests.
        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
        validator: RegularExpressionValidator { regularExpression: /(?!root$)[a-z][a-z0-9_-]{0,30}/ }
        placeholderText: qsTr("Lowercase letters, digits, - and _")
        onEdited: page.userNameEdited = true
    }
}
