.PHONY: mac test clean

mac:   ## Mac uygulamasını derler (mac/build/LinkCepte.app ve .zip)
	bash mac/scripts/build_app.sh

test:  ## Birim testlerini çalıştırır
	swift test --package-path mac

clean:
	rm -rf mac/build mac/.build
