'use strict';

module.exports = function createLightPorter(deps) {
  const { getField } = deps;

  function emitLight(nodeId, componentId, doc, builder, reporter) {
    const type = Number(getField(doc, 'm_Type', 1) || 1);
    if (type !== 1) {
      reporter.medium('LIGHT_TYPE_APPROXIMATED', '', '', `Unity light type ${type} is approximated as cc.DirectionalLight`);
    }
    builder.addDirectionalLight(nodeId, componentId, doc, `cmp-light-${componentId}`);
  }

  return { emitLight };
};
