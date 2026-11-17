# The assistant: answers and actions, on the computer or online.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec)/assistant assistant
	install -Dm644 -t $(libexec)/assistant actions.py models.py skills.py web.py providers.py chatgpt.py
	install -Dm644 -t $(data)/assistant models.json
	install -Dm644 -t $(data)/assistant/skills skills/*.md
	install -Dm644 -t $(userunit) assistant.socket assistant.service language-model@.socket \
	  language-model@.service language-model-ready@.service llama-server@.service
	install -d $(userunit)/sockets.target.wants
	ln -sf ../assistant.socket $(userunit)/sockets.target.wants/assistant.socket
