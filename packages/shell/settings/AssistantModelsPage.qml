// A page of Settings > Assistant: every model the assistant can answer with,
// the one in use, and adding online ones (assistant/providers.py). Gemma runs
// on this computer. Online forms remain for future provider integrations;
// no online provider is registered in the shipped system.
pragma ComponentBehavior: Bound
import QtQuick
import qs.controls
import qs.services

Column {
    id: page

    // The form for adding a model from the registered providers.
    property bool adding
    property string provider: Object.keys(Assistant.providers)[0] ?? ""
    property string chosen
    readonly property string listing: provider
    readonly property var listed: Assistant.providerModels[listing] ?? null
    readonly property bool byPlan: (Assistant.providers[listing]?.auth ?? "plan") === "plan"

    function start() {
        if (!Object.keys(Assistant.providers).length)
            return;
        adding = true;
        chosen = "";
        keyField.text = "";
        nameField.text = "";
        Assistant.addError = "";
        if (byPlan && Assistant.chatgpt)
            Assistant.listProvider("chatgpt", "");
    }

    function find() {
        chosen = "";
        Assistant.listProvider(listing, byPlan ? "" : keyField.text);
    }

    function describe(model: var): string {
        if (model.where === "local")
            return `On this computer · ${model.ready ? "nothing you ask leaves it" : "not downloaded yet: download it in Settings > Assistant"}`;
        const provider = Assistant.providers[model.provider];
        return [provider?.name ?? "Online", provider?.auth === "plan" ? "your ChatGPT plan" : "your API key", model.model].filter(t => t).join(" · ");
    }

    spacing: 12

    onListingChanged: {
        chosen = "";
        if (adding && byPlan && Assistant.chatgpt)
            Assistant.listProvider("chatgpt", "");
    }

    Connections {
        target: Assistant

        function onModelAdded() {
            page.adding = false;
        }

        function onChatgptChanged() {
            if (page.adding && page.byPlan && Assistant.chatgpt)
                Assistant.listProvider("chatgpt", "");
        }
    }

    component List: Rectangle {
        default property alias rows: column.data

        width: page.width
        height: column.height + 2
        color: Theme.surface
        border.color: Theme.line

        Column {
            id: column
            x: 1
            y: 1
            width: parent.width - 2
        }
    }

    component Field: Rectangle {
        id: box

        property alias text: field.text
        property alias secret: field.echoMode
        property string hint

        width: parent?.width ?? 0
        height: 32
        color: Theme.surface
        border.color: Theme.lineStrong

        TextInput {
            id: field
            anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
            color: Theme.textStrong
            selectionColor: Theme.accent
            font { family: Theme.font; pixelSize: 12 }
            clip: true

            Text {
                visible: !field.text
                text: box.hint
                color: Theme.textMuted
                font: field.font
            }
        }
    }

    component Link: Text {
        signal tapped

        color: Theme.accent
        font { family: Theme.font; pixelSize: 12; weight: Font.Medium }

        TapHandler {
            onTapped: parent.tapped()
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    component Note: Text {
        width: page.width - 32
        wrapMode: Text.Wrap
        color: Theme.textMuted
        font { family: Theme.font; pixelSize: 12 }
    }
    
    Text {
        width: page.width
        wrapMode: Text.Wrap
        text: "The assistant answers with one model at a time: choose it here, or in the assistant. Gemma runs on this "
            + "computer."
            + (Object.keys(Assistant.providers).length
                ? " An online model gets what you ask, and what the assistant reads for it, on its provider's servers, under your account there."
                : " No online AI provider is enabled.")
        color: Theme.textMuted
        font { family: Theme.font; pixelSize: 12 }
    }

    // Every model.
    List {
        Repeater {
            model: Assistant.models

            Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool current: modelData.id === Assistant.model?.id

                width: parent?.width ?? 0
                height: texts.height + 24

                Rectangle {
                    visible: row.index > 0
                    width: parent.width
                    height: 1
                    color: Theme.lineSoft
                }
                Rectangle {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: row.modelData.color

                    Text {
                        anchors.centerIn: parent
                        text: row.modelData.mark
                        color: Theme.textOnAccent
                        font { family: Theme.font; pixelSize: 11; weight: Font.Bold }
                    }
                }
                Column {
                    id: texts
                    x: 52
                    y: 12
                    width: parent.width - x - 16 - actions.width - 16
                    spacing: 3

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: Theme.textStrong
                        font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: page.describe(row.modelData)
                        color: Theme.textMuted
                        font { family: Theme.font; pixelSize: 12 }
                    }
                }
                Row {
                    id: actions
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 14

                    Text {
                        visible: row.current
                        text: "In use"
                        color: Theme.textBody
                        font { family: Theme.font; pixelSize: 12 }
                    }
                    Link {
                        visible: !row.current
                        text: "Use"
                        onTapped: Assistant.chooseModel(row.modelData.id)
                    }
                    Link {
                        visible: row.modelData.own
                        text: "Remove"
                        color: Theme.dangerInk
                        onTapped: Assistant.removeModel(row.modelData.id)
                    }
                }
            }
        }
    }

    // The ChatGPT account, while signed in: OpenAI asks that people see the
    // plan is used, and where to manage its usage.
    List {
        visible: Assistant.providers.chatgpt !== undefined && Assistant.chatgpt !== null

        Item {
            width: parent.width
            height: account.height + 24

            Column {
                id: account
                x: 16
                y: 12
                width: parent.width - 32 - accountActions.width - 16
                spacing: 3

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: `ChatGPT · ${Assistant.chatgpt?.email || "signed in"}`
                    color: Theme.textStrong
                    font { family: Theme.font; pixelSize: 13; weight: Font.Medium }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "Using your ChatGPT plan: what the assistant asks counts toward its usage limits, "
                        + "and is never billed otherwise."
                    color: Theme.textMuted
                    font { family: Theme.font; pixelSize: 12 }
                }
            }
            Row {
                id: accountActions
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 14

                Link {
                    text: "Manage usage"
                    onTapped: Qt.openUrlExternally(Assistant.providers.chatgpt?.usage ?? "https://chatgpt.com/settings/usage")
                }
                Link {
                    text: "Sign out"
                    color: Theme.dangerInk
                    onTapped: Assistant.signOutChatgpt()
                }
            }
        }
    }

    Item {
        visible: Object.keys(Assistant.providers).length > 0
        width: page.width
        height: 34

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Add a model"
            color: Theme.textStrong
            font { family: Theme.font; pixelSize: 13; weight: Font.DemiBold }
        }
        DialogButton {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: !page.adding
            text: "Add"
            onActivated: page.start()
        }
    }

    // Adding one: the provider, how to sign in, the model, and its name.
    List {
        visible: page.adding && Object.keys(Assistant.providers).length > 0

        Column {
            width: parent.width
            padding: 16
            spacing: 10

            SettingsChoice {
                options: Object.entries(Assistant.providers).map(([id, info]) => [info.name, id])
                visible: options.length > 1
                selected: page.provider
                onPicked: value => page.provider = value
            }
            // By the ChatGPT plan.
            Column {
                visible: page.byPlan
                width: parent.width - 32
                spacing: 8

                Note {
                    width: parent.width
                    text: Assistant.chatgpt
                        ? `Signed in as ${Assistant.chatgpt.email || "your ChatGPT account"}. Choose a model of your plan.`
                        : "Uses your ChatGPT Plus or Pro plan: no API key, and nothing billed beyond the plan. "
                          + "You sign in on OpenAI's page, in your browser."
                }
                DialogButton {
                    visible: !Assistant.chatgpt
                    strong: true
                    text: Assistant.signingIn ? "Finish in your browser…" : "Continue with ChatGPT"
                    onActivated: Assistant.signInChatgpt()
                }
                Note {
                    visible: Assistant.signInError !== ""
                    width: parent.width
                    text: Assistant.signInError
                    color: Theme.dangerInk
                }
            }

            // By an API key.
            Column {
                visible: !page.byPlan
                width: parent.width - 32
                spacing: 8

                Note {
                    width: parent.width
                    text: "An API key for the selected provider. The provider bills its use. The key stays in your keyring."
                }
                Row {
                    width: parent.width
                    spacing: 8

                    Field {
                        id: keyField
                        width: parent.width - findButton.width - 8
                        hint: Assistant.models.some(m => m.provider === page.provider) ? "Kept; or enter a new key" : "API key"
                        secret: TextInput.Password
                    }
                    DialogButton {
                        id: findButton
                        text: "Find models"
                        onActivated: page.find()
                    }
                }
            }

            // The models found, to choose one, and its name.
            Note {
                visible: page.listed?.listing === true
                text: "Asking for its models…"
            }
            Note {
                visible: (page.listed?.error ?? "") !== ""
                text: page.listed?.error ?? ""
                color: Theme.dangerInk
            }
            SettingsSelect {
                visible: (page.listed?.models?.length ?? 0) > 0
                width: Math.min(360, parent.width - 32)
                options: [["Choose a model", ""], ...(page.listed?.models ?? []).map(m => [m.name, m.model])]
                selected: page.chosen
                onPicked: value => page.chosen = value
            }
            Field {
                id: nameField
                visible: page.chosen !== ""
                width: Math.min(360, parent.width - 32)
                hint: `Name in the assistant: ${page.listed?.models?.find(m => m.model === page.chosen)?.name ?? ""}`
            }
            Note {
                visible: Assistant.addError !== ""
                text: Assistant.addError
                color: Theme.dangerInk
            }
            Row {
                spacing: 8

                DialogButton {
                    visible: page.chosen !== ""
                    text: "Add"
                    strong: true
                    onActivated: Assistant.addModel(page.listing, page.chosen,
                        nameField.text.trim() || (page.listed?.models?.find(m => m.model === page.chosen)?.name ?? ""),
                        page.byPlan ? "" : keyField.text)
                }
                DialogButton {
                    text: "Cancel"
                    onActivated: page.adding = false
                }
            }
        }
    }
}
