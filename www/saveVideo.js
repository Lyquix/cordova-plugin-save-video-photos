var exec = require('cordova/exec');

/**
 * Save a video at file:// URI to Photos.
 * @param {string} uri - file:// or cdvfile:// path
 * @param {string|null} album - album name or null
 * @param {function} success
 * @param {function} error
 */
exports.save = function(uri, album, success, error) {
  exec(success, error, "SaveVideo", "save", [uri, album || null]);
};
