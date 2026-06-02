import SwiftUI
import WebKit

struct HanziWriterAnimationView: UIViewRepresentable {
    let literal: String
    let reloadID: Int

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLiteral != literal || context.coordinator.lastReloadID != reloadID else {
            return
        }

        context.coordinator.lastLiteral = literal
        context.coordinator.lastReloadID = reloadID
        webView.loadHTMLString(html(), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastLiteral: String?
        var lastReloadID: Int?
    }

    private func html() -> String {
        do {
            let script = try HanziWriterAssetStore.shared.script()
            let characterData = try HanziWriterAssetStore.shared.characterData(for: literal)
            let literalJSON = jsonStringLiteral(literal)

            return """
            <!doctype html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
              <style>
                html, body {
                  margin: 0;
                  padding: 0;
                  width: 100%;
                  height: 100%;
                  overflow: hidden;
                  background: transparent;
                  -webkit-user-select: none;
                }

                #writer {
                  width: 100vw;
                  height: 100vw;
                }
              </style>
            </head>
            <body>
              <div id="writer"></div>
              <script>
              \(script)
              </script>
              <script>
                const character = \(literalJSON);
                const characterData = \(characterData);

                function size() {
                  return Math.max(220, Math.min(window.innerWidth, window.innerHeight));
                }

                function render() {
                  const writerNode = document.getElementById('writer');
                  writerNode.innerHTML = '';

                  const side = size();
                  writerNode.style.width = side + 'px';
                  writerNode.style.height = side + 'px';

                  const writer = HanziWriter.create('writer', character, {
                    width: side,
                    height: side,
                    padding: Math.round(side * 0.08),
                    strokeAnimationSpeed: 1.1,
                    delayBetweenStrokes: 260,
                    strokeColor: '#171714',
                    radicalColor: '#1f7769',
                    outlineColor: '#dddacf',
                    drawingColor: '#d94032',
                    showCharacter: false,
                    showOutline: true,
                    charDataLoader: function(_, onComplete) {
                      onComplete(characterData);
                    }
                  });

                  writer.animateCharacter();
                }

                render();
              </script>
            </body>
            </html>
            """
        } catch {
            return """
            <!doctype html>
            <html>
            <body style="margin:0;display:flex;align-items:center;justify-content:center;height:100vh;background:transparent;font:17px -apple-system;color:#777;text-align:center;">
              <div>\(escapeHTML(error.localizedDescription))</div>
            </body>
            </html>
            """
        }
    }

    private func jsonStringLiteral(_ value: String) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [value]),
            let json = String(data: data, encoding: .utf8),
            json.count >= 2
        else {
            return "\"\""
        }

        return String(json.dropFirst().dropLast())
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
