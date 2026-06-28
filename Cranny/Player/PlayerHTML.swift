import Foundation

/// The local web content for the player: a log/error bridge (injected at documentStart)
/// and the IFrame Player page (loaded with a fake-https baseURL).
enum PlayerHTML {
    /// Injected via WKUserScript at `.atDocumentStart` so it captures everything,
    /// including errors thrown by the IFrame API script itself. Routes console + uncaught
    /// errors through the single `cranny` message channel → Swift `Logger`.
    static let logBridgeJS = """
    (function () {
      function send(kind, level, args) {
        try {
          var text = Array.prototype.map.call(args, function (a) {
            if (a instanceof Error) return a.stack || (a.name + ': ' + a.message);
            if (typeof a === 'object') { try { return JSON.stringify(a); } catch (_) { return String(a); } }
            return String(a);
          }).join(' ');
          window.webkit.messageHandlers.cranny.postMessage({ kind: kind, level: level, text: text });
        } catch (_) {}
      }
      ['log', 'info', 'warn', 'error', 'debug'].forEach(function (level) {
        var orig = console[level] ? console[level].bind(console) : function () {};
        console[level] = function () { try { orig.apply(null, arguments); } catch (_) {} send('log', level, arguments); };
      });
      window.addEventListener('error', function (e) {
        var where = (e.filename || '?') + ':' + (e.lineno || 0) + ':' + (e.colno || 0);
        send('exception', 'error', [where, (e.error && e.error.stack) || e.message]);
      }, true);
      window.addEventListener('unhandledrejection', function (e) {
        var r = e.reason;
        send('exception', 'error', ['unhandledrejection', (r && r.stack) || r]);
      });
    })();
    """

    /// The player page. `origin` must equal the baseURL host passed to `loadHTMLString`.
    static func page(origin: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <!-- Emit a Referer YouTube accepts (avoids error 153). -->
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <style>
            html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
            #player, iframe { width: 100%; height: 100%; border: 0; }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            var ORIGIN = "\(origin)";
            function post(kind, payload) {
              try {
                var m = Object.assign({ kind: kind }, payload || {});
                window.webkit.messageHandlers.cranny.postMessage(m);
              } catch (e) {}
            }

            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            document.head.appendChild(tag);

            var player, ticker = null;

            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                playerVars: {
                  playsinline: 1, enablejsapi: 1, origin: ORIGIN,
                  rel: 0, controls: 1, modestbranding: 1
                },
                events: {
                  onReady: function () { post('ready', {}); },
                  onStateChange: onState,
                  onError: function (e) { post('error', { code: e.data }); }
                }
              });
            }

            function onState(e) {
              var dur = (player && player.getDuration) ? player.getDuration() : 0;
              post('state', { state: e.data, duration: dur });
              if (e.data === 1) { startTicker(); } else { stopTicker(); }
            }

            function startTicker() {
              stopTicker();
              ticker = setInterval(function () {
                if (player && player.getCurrentTime) {
                  post('time', { t: player.getCurrentTime(), d: player.getDuration() });
                }
              }, 500);
            }
            function stopTicker() { if (ticker) { clearInterval(ticker); ticker = null; } }

            window.cranny = {
              load:  function (id) { player.loadVideoById({ videoId: id }); },
              play:  function () { player.playVideo(); },
              pause: function () { player.pauseVideo(); },
              stop:  function () { player.stopVideo(); },
              seek:  function (s) { player.seekTo(s, true); }
            };
          </script>
        </body>
        </html>
        """
    }
}
