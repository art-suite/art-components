// generated by Neptune Namespaces v4.x.x
// file: tests/namespace.js

module.exports = require('neptune-namespaces').addNamespace(
  'Tests',
  (class Tests extends Neptune.PackageNamespace {})
  ._configureNamespace(require('../../package.json'))
);
require('./Art.Components/namespace');
require('./Mocks/namespace');