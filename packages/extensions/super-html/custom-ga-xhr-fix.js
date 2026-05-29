;(function () {
    if (window.__superHtmlGaXhrFixInstalled) return;
    window.__superHtmlGaXhrFixInstalled = true;

    var NativeXHR = window.XMLHttpRequest;
    var NativeURL = window.URL;
    var originalBoot = window.super_boot_engine;

    function restoreUsableURL() {
        if (!NativeURL || window.__superHtmlGaUrlFixed) return;
        window.__superHtmlGaUrlFixed = true;

        function SuperHtmlURL(input, base) {
            var baseText = typeof base === "string" ? base : base && base.href;
            if (baseText && (baseText.indexOf("data:") === 0 || baseText.indexOf("_SUPER_URL") === 0)) {
                baseText = baseText.replace("data:", "").replace("_SUPER_URL", "");
                var parts = baseText.split("/");
                this.href = baseText.replace(parts[parts.length - 1], input);
                return this;
            }
            return new NativeURL(input, base);
        }

        try {
            Object.getOwnPropertyNames(NativeURL).forEach(function (key) {
                if (!(key in SuperHtmlURL)) SuperHtmlURL[key] = NativeURL[key];
            });
            SuperHtmlURL.prototype = NativeURL.prototype;
        } catch (error) {}

        if (NativeURL.createObjectURL) {
            SuperHtmlURL.createObjectURL = NativeURL.createObjectURL.bind(NativeURL);
        }
        if (NativeURL.revokeObjectURL) {
            SuperHtmlURL.revokeObjectURL = NativeURL.revokeObjectURL.bind(NativeURL);
        }

        window.URL = SuperHtmlURL;
    }

    function toArrayBuffer(dataUri) {
        var comma = dataUri.indexOf(",");
        var encoded = comma >= 0 ? dataUri.substring(comma + 1) : dataUri;
        var binary = window.atob(encoded);
        var bytes = new Uint8Array(binary.length);
        for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        return bytes.buffer;
    }

    function toBlob(dataUri) {
        var typeMatch = /^data:([^;,]+)/.exec(dataUri);
        return new Blob([toArrayBuffer(dataUri)], { type: typeMatch ? typeMatch[1] : "" });
    }

    function getEmbeddedResource(url) {
        if (typeof window.getRes !== "function") return undefined;
        try {
            return window.getRes(url);
        } catch (error) {
            return undefined;
        }
    }

    function externalXhrMode() {
        var explicitMode = window.__SUPER_HTML_EXTERNAL_XHR_MODE;
        if (explicitMode) return String(explicitMode).toLowerCase();

        var channel = String(window.super_html_channel || "").toLowerCase();
        if (channel === "applovin") return "block";

        return "native";
    }

    function shouldBlockExternalXHR() {
        return externalXhrMode() === "block";
    }

    function installXHRBridge() {
        if (!NativeXHR || window.__superHtmlGaXhrBridgeInstalled) return;
        window.__superHtmlGaXhrBridgeInstalled = true;

        window._XMLLocalRequest = function SuperHtmlXMLLocalRequest() {
            var nativeXhr = new NativeXHR();
            var local = false;
            var blocked = false;
            var localBody = null;
            var listeners = {};
            var state = {
                readyState: 0,
                response: null,
                responseText: "",
                responseType: "",
                responseURL: "",
                responseXML: null,
                status: 0,
                statusText: "",
                timeout: 0,
                upload: nativeXhr.upload,
                withCredentials: false
            };
            var self = this;

            function defineForwardedProperty(name) {
                Object.defineProperty(self, name, {
                    configurable: true,
                    enumerable: true,
                    get: function () {
                        if (local || blocked) return state[name];
                        try {
                            return nativeXhr[name];
                        } catch (error) {
                            return state[name];
                        }
                    },
                    set: function (value) {
                        state[name] = value;
                        try {
                            nativeXhr[name] = value;
                        } catch (error) {}
                    }
                });
            }

            [
                "readyState",
                "response",
                "responseText",
                "responseType",
                "responseURL",
                "responseXML",
                "status",
                "statusText",
                "timeout",
                "upload",
                "withCredentials",
                "onabort",
                "onerror",
                "onload",
                "onloadend",
                "onloadstart",
                "onprogress",
                "onreadystatechange",
                "ontimeout"
            ].forEach(defineForwardedProperty);

            function emit(type, event) {
                event = event || { type: type, target: self, currentTarget: self };
                var handler = state["on" + type];
                if (typeof handler === "function") handler.call(self, event);
                (listeners[type] || []).slice().forEach(function (listener) {
                    listener.call(self, event);
                });
            }

            this.addEventListener = function (type, listener, options) {
                (listeners[type] = listeners[type] || []).push(listener);
                if (nativeXhr.addEventListener) nativeXhr.addEventListener(type, listener, options);
            };

            this.removeEventListener = function (type, listener, options) {
                var bucket = listeners[type] || [];
                var index = bucket.indexOf(listener);
                if (index >= 0) bucket.splice(index, 1);
                if (nativeXhr.removeEventListener) nativeXhr.removeEventListener(type, listener, options);
            };

            this.dispatchEvent = function (event) {
                emit(event.type, event);
                return true;
            };

            this.open = function (method, url, async, user, password) {
                localBody = getEmbeddedResource(url);
                local = localBody !== undefined && localBody !== null;
                blocked = !local && shouldBlockExternalXHR();
                if (local || blocked) {
                    state.readyState = 1;
                    state.status = local ? 200 : 0;
                    state.statusText = local ? "OK" : "";
                    state.responseURL = String(url);
                    emit("readystatechange");
                    return;
                }
                return nativeXhr.open(method, url, async !== false, user, password);
            };

            this.setRequestHeader = function (name, value) {
                if (!local && !blocked) nativeXhr.setRequestHeader(name, value);
            };

            this.overrideMimeType = function (mimeType) {
                if (!local && !blocked && nativeXhr.overrideMimeType) nativeXhr.overrideMimeType(mimeType);
            };

            this.getResponseHeader = function (name) {
                return local || blocked ? null : nativeXhr.getResponseHeader(name);
            };

            this.getAllResponseHeaders = function () {
                return local || blocked ? "" : nativeXhr.getAllResponseHeaders();
            };

            this.abort = function () {
                if (!local && !blocked) return nativeXhr.abort();
                state.readyState = 0;
                state.status = 0;
                emit("abort");
                emit("loadend");
            };

            this.send = function (body) {
                if (blocked) {
                    window.__superHtmlBlockedExternalRequests = window.__superHtmlBlockedExternalRequests || [];
                    window.__superHtmlBlockedExternalRequests.push(state.responseURL);
                    setTimeout(function () {
                        state.readyState = 4;
                        state.status = 0;
                        state.statusText = "";
                        state.response = "";
                        state.responseText = "";
                        emit("readystatechange");
                        emit("error");
                        emit("loadend");
                    }, 0);
                    return;
                }

                if (!local) return nativeXhr.send(body);

                setTimeout(function () {
                    try {
                        var responseType = state.responseType || "";
                        var text = String(localBody == null ? "" : localBody);
                        if (responseType === "json") {
                            state.response = JSON.parse(text);
                            state.responseText = text;
                        } else if (responseType === "arraybuffer") {
                            state.response = toArrayBuffer(text);
                            state.responseText = "";
                        } else if (responseType === "blob") {
                            state.response = toBlob(text);
                            state.responseText = "";
                        } else {
                            state.response = text;
                            state.responseText = text;
                        }
                        state.readyState = 4;
                        emit("readystatechange");
                        emit("load");
                        emit("loadend");
                    } catch (error) {
                        state.readyState = 4;
                        state.status = 500;
                        emit("readystatechange");
                        emit("error", { type: "error", target: self, currentTarget: self, error: error });
                        emit("loadend");
                    }
                }, 0);
            };
        };
    }

    window.super_boot_engine = function () {
        restoreUsableURL();
        var result = originalBoot && originalBoot.apply(this, arguments);
        installXHRBridge();
        return result;
    };
})();
