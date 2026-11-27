# The assistant: answers and actions, on the computer or online.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec)/assistant src/assistant
	install -Dm644 -t $(libexec)/assistant src/actions.py src/models.py src/skills.py src/web.py src/providers.py src/chatgpt.py
	install -Dm644 -t $(data)/assistant data/models.json
	install -Dm644 -t $(data)/assistant/skills data/skills/*.md
	install -Dm644 -t $(userunit) system/assistant.socket system/assistant.service system/language-model@.socket \
	  system/language-model@.service system/language-model-ready@.service system/llama-server@.service
	install -d $(userunit)/sockets.target.wants
	ln -sf ../assistant.socket $(userunit)/sockets.target.wants/assistant.socket
# What it shows in the shell: its QML, the module qs.assistant, in the shell's
# folder, and what it adds there (packages/shell/src/services/Features.qml).
	install -Dm644 -t $(data)/shell/assistant src/shell/*.qml src/shell/assistant.js src/shell/qmldir
	install -Dm644 src/feature.qml $(data)/shell/features/assistant.qml
