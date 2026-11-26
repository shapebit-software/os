// What the assistant shows while its model isn't on this computer: what the
// model is, and the way to get it, through the one queue (Downloads.qml), with
// how far it is. Only those who may download extras can (Extras.qml).
import QtQuick
import qs.controls
import qs.services

Column {
    id: get

    readonly property var extra: Assistant.extra
    readonly property var progress: Assistant.download

    spacing: 10

    Text {
        width: get.width
        text: !get.extra ? (Assistant.model ? `${Assistant.model.name} can't be reached.` : "No model is set up for the assistant.")
            : `The assistant runs on this computer, so nothing you ask leaves it. It needs its model, ${get.extra.credits?.[0]?.work ?? Assistant.model?.name ?? ""}, `
              + `a download of ${Extras.sizeOf(get.extra)}.`
        color: Theme.ink
        wrapMode: Text.Wrap
        lineHeight: 1.4
        font { family: Theme.font; pixelSize: 13 }
    }
    Text {
        width: get.width
        visible: text !== ""
        text: !get.extra ? ""
            : get.progress?.state === "failed" ? get.progress.note
            : get.progress ? `${get.progress.note}${get.progress.percent > 0 ? ` ${get.progress.percent}%` : "…"} · Settings > Downloads shows it too`
            : !Extras.writable ? "An administrator can download it, in Settings > Assistant."
            : get.extra.fits === false ? "This computer has little memory for it, so it may be slow." : ""
        color: get.progress?.state === "failed" ? Theme.danger : Theme.inkFaint
        wrapMode: Text.Wrap
        font { family: Theme.font; pixelSize: 12 }
    }
    Rectangle {
        visible: get.progress?.state === "working"
        width: get.width
        height: 3
        color: Theme.veil(0.08)

        Rectangle {
            width: parent.width * (get.progress?.percent ?? 0) / 100
            height: parent.height
            color: Theme.accent
        }
    }
    DialogButton {
        visible: get.extra !== null && Extras.writable && (!get.progress || get.progress.state === "failed")
        text: get.progress?.state === "failed" ? "Try again" : `Download · ${get.extra ? Extras.sizeOf(get.extra) : ""}`
        strong: true
        onActivated: Assistant.getModel()
    }
}
