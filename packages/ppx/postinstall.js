const path = require("path");
const fs = require("fs");

const installMacLinuxBinary = (binary) => {
  const source = path.join(__dirname, binary);
  if (fs.existsSync(source)) {
    const target = path.join(__dirname, "ppx");
    fs.renameSync(source, target);
    fs.chmodSync(target, 0o777);
  }
};

const installWindowsBinary = () => {
  const source = path.join(__dirname, "ppx-windows.exe");
  if (fs.existsSync(source)) {
    const target = path.join(__dirname, "ppx.exe");
    fs.renameSync(source, target);

    const windowsScript = path.join(__dirname, "ppx.cmd");
    if (fs.existsSync(windowsScript)) {
      fs.unlinkSync(windowsScript);
    }
  }
};

switch (process.platform) {
  case "linux":
    installMacLinuxBinary(
      process.arch === "arm64" ? "ppx-linux-arm64.exe" : "ppx-linux-x64.exe"
    );
    break;
  case "darwin":
    installMacLinuxBinary(
      process.arch === "arm64" ? "ppx-osx-arm64.exe" : "ppx-osx-x64.exe"
    );
    break;
  case "win32":
    installWindowsBinary();
    break;
  default:
    console.warn(`No release available for "${process.platform}"`);
    process.exit(1);
}
