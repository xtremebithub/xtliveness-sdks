// The demo uses the SDK from the folder above (built into ../dist by setup.sh), so Metro must watch that folder and find react, react-native and
// react-native-webview in THIS app only: a second copy of React would break the app.
const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const sdk = path.resolve(__dirname, '..');
const config = getDefaultConfig(__dirname);
config.watchFolders = [sdk];
config.resolver.nodeModulesPaths = [path.resolve(__dirname, 'node_modules')];
config.resolver.extraNodeModules = { 'xtliveness-react-native': sdk };
config.resolver.disableHierarchicalLookup = true;
module.exports = config;
