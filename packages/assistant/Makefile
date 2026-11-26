# The assistant: answers and actions, on the computer or online.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec)/assistant src/assistant
	install -Dm644 -t $(libexec)/assistant src/actions.py src/models.py src/skills.py src/web.py src/providers.py src/chatgpt.py
	install -Dm644 -t $(data)/assistant data/models.json
	install -Dm644 -t $(data)/assistant/skills data/skills/*.md
	install -Dm644 -t $(userunit) system/assistant.socket system/assistant.service system/language-model@.socket \
	  system/language-model@.service system/language-model-ready@.service system/llama-server@.service
	install -d $(userunit)/sockets.target.wants
	ln -sf ../assistant.socket $(userunit)/sockets.target.wants/assistant.socket
