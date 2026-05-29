"use strict";

Object.defineProperty(exports, "__esModule", { value: true });
exports.onAfterBuild = void 0;

const CocosMain = require("../platform/cocos/cocos_main").default;
const wasmSupport = require("../../custom-wasm-support");

function isWebBuild(options) {
    return options && (options.platform === "web-mobile" || options.platform === "web-desktop");
}

function isIgnorableCoreError(error) {
    const message = String((error && error.message) || error || "");
    const stack = String((error && error.stack) || "");
    return message.includes("Unexpected token '<'") && stack.includes("dist\\core\\build.js");
}

function runSuperHtml(buildDir) {
    return new Promise((resolve, reject) => {
        const canHandleProcessErrors = typeof process !== "undefined" && process && process.on;
        let settled = false;

        const cleanup = () => {
            if (canHandleProcessErrors && process.removeListener) {
                process.removeListener("uncaughtException", onUncaughtException);
            }
        };

        const finish = () => {
            if (settled) return;
            settled = true;
            cleanup();
            resolve(true);
        };

        const fail = (error) => {
            if (settled) return;
            settled = true;
            cleanup();
            reject(error);
        };

        const onUncaughtException = (error) => {
            if (isIgnorableCoreError(error)) {
                console.warn("[super-html] ignored non-critical core JSON response error:", error.message);
                return;
            }
            fail(error);
        };

        if (canHandleProcessErrors) {
            process.on("uncaughtException", onUncaughtException);
        }

        try {
            new CocosMain(Editor.App.version, buildDir, finish);
        } catch (error) {
            fail(error);
        }
    });
}

exports.onAfterBuild = async function onAfterBuild(options, result) {
    if (!isWebBuild(options)) return;

    const buildDir = result && result.dest;
    if (!buildDir) return;

    const hiddenWasmFiles = wasmSupport.hideWasmFiles(buildDir);

    try {
        await runSuperHtml(buildDir);
    } catch (error) {
        console.error(error);
    } finally {
        wasmSupport.restoreWasmFiles(hiddenWasmFiles);
    }

    try {
        const patched = await wasmSupport.patchGeneratedHtml(buildDir, hiddenWasmFiles);
        if (patched.resources) {
            console.log(
                `[super-html] wasm support: embedded ${patched.resources} wasm file(s), patched ${patched.html} html file(s), ${patched.zip} zip file(s).`
            );
        }
    } catch (error) {
        console.error("[super-html] wasm support patch failed", error);
    } finally {
        wasmSupport.cleanupHiddenWasmFiles(hiddenWasmFiles);
    }
};
