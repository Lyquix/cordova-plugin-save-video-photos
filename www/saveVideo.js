var exec = require('cordova/exec');

/**
 * Save a video at file:// or cdvfile:// URI to Photos.
 * @param {string} uri
 * @param {string|null} album  Album name or null
 * @param {Function} success
 * @param {Function} error
 */
exports.save = function (uri, album, success, error) {
  exec(success, error, 'SaveVideo', 'save', [uri, album || null]);
};
