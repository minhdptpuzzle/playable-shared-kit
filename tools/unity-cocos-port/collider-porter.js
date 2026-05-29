'use strict';

const { UNITY_3D_COLLIDER_DEPTH } = require('./constants');
const { finiteNumber } = require('./core-utils');

module.exports = function createColliderPorter(deps) {
  const {
    getField,
    parseUnityPolygonColliderPaths,
    boundsForUnityPolygonPaths,
  } = deps;

  function unityRigidBody2DTypeToCocosType(unityBodyType) {
    const value = Number(unityBodyType || 0);
    if (value === 2) return 2;
    if (value === 1) return 4;
    return 1;
  }

  function emitRigidbody2D(nodeId, componentId, doc, gameObject, model, builder, reporter) {
    if (!model.is3DObject) {
      reporter.low('COMPONENT_UNSUPPORTED', model.file, gameObject.name, 'Unity Rigidbody2D is skipped because this prefab is not detected as a 3D object');
      return;
    }

    builder.addRigidBody(nodeId, componentId, {
      type: unityRigidBody2DTypeToCocosType(getField(doc, 'm_BodyType', 0)),
      mass: finiteNumber(getField(doc, 'm_Mass', 1), 1),
      linearDamping: finiteNumber(getField(doc, 'm_LinearDamping', getField(doc, 'm_LinearDrag', 0.1)), 0.1),
      angularDamping: finiteNumber(getField(doc, 'm_AngularDamping', getField(doc, 'm_AngularDrag', 0.1)), 0.1),
      useGravity: finiteNumber(getField(doc, 'm_GravityScale', 1), 1) !== 0,
      allowSleep: Number(getField(doc, 'm_SleepingMode', 1) || 0) !== 0,
    }, `cmp-rigid-body-${componentId}`);
  }

  function emitCircleCollider2D(nodeId, componentId, doc, gameObject, model, builder, reporter) {
    if (!model.is3DObject) {
      reporter.low('COMPONENT_UNSUPPORTED', model.file, gameObject.name, 'Unity CircleCollider2D is skipped because this prefab is not detected as a 3D object');
      return;
    }

    const offset = getField(doc, 'm_Offset', { x: 0, y: 0 });
    builder.addSphereCollider(nodeId, componentId, {
      enabled: Number(getField(doc, 'm_Enabled', 1) || 0) !== 0,
      isTrigger: Number(getField(doc, 'm_IsTrigger', 0) || 0) !== 0,
      center: {
        x: finiteNumber(offset?.x, 0),
        y: finiteNumber(offset?.y, 0),
        z: 0,
      },
      radius: Math.abs(finiteNumber(getField(doc, 'm_Radius', 0.5), 0.5)),
    }, `cmp-sphere-collider-${componentId}`);
  }

  function emitBoxCollider2D(nodeId, componentId, doc, gameObject, model, builder, reporter) {
    const offset = getField(doc, 'm_Offset', { x: 0, y: 0 });
    const size = getField(doc, 'm_Size', { x: 1, y: 1 });
    if (model.is3DObject) {
      builder.addBoxCollider(nodeId, componentId, {
        enabled: Number(getField(doc, 'm_Enabled', 1) || 0) !== 0,
        isTrigger: Number(getField(doc, 'm_IsTrigger', 0) || 0) !== 0,
        center: {
          x: finiteNumber(offset?.x, 0),
          y: finiteNumber(offset?.y, 0),
          z: 0,
        },
        size: {
          x: Math.abs(finiteNumber(size?.x, 1)),
          y: Math.abs(finiteNumber(size?.y, 1)),
          z: UNITY_3D_COLLIDER_DEPTH,
        },
      }, `cmp-box-collider-${componentId}`);
      return;
    }

    builder.addBoxCollider2D(nodeId, componentId, {
      enabled: Number(getField(doc, 'm_Enabled', 1) || 0) !== 0,
      sensor: Number(getField(doc, 'm_IsTrigger', 0) || 0) !== 0,
      offset: {
        x: finiteNumber(offset?.x, 0),
        y: finiteNumber(offset?.y, 0),
      },
      size: {
        x: Math.abs(finiteNumber(size?.x, 1)),
        y: Math.abs(finiteNumber(size?.y, 1)),
      },
    }, `cmp-box-collider-2d-${componentId}`);
  }

  function polygonPathArea(points) {
    if (!Array.isArray(points) || points.length < 3) return 0;
    let area = 0;
    for (let index = 0; index < points.length; index += 1) {
      const current = points[index];
      const next = points[(index + 1) % points.length];
      area += (Number(current?.x || 0) * Number(next?.y || 0)) - (Number(next?.x || 0) * Number(current?.y || 0));
    }
    return Math.abs(area * 0.5);
  }

  function emitPolygonCollider2D(nodeId, componentId, doc, gameObject, model, builder, reporter) {
    const offset = getField(doc, 'm_Offset', { x: 0, y: 0 });
    const paths = parseUnityPolygonColliderPaths(doc);
    if (model.is3DObject) {
      const bounds = boundsForUnityPolygonPaths(paths, offset) || {
        center: {
          x: finiteNumber(offset?.x, 0),
          y: finiteNumber(offset?.y, 0),
          z: 0,
        },
        size: {
          x: 1,
          y: 1,
          z: UNITY_3D_COLLIDER_DEPTH,
        },
      };

      builder.addBoxCollider(nodeId, componentId, {
        enabled: Number(getField(doc, 'm_Enabled', 1) || 0) !== 0,
        isTrigger: Number(getField(doc, 'm_IsTrigger', 0) || 0) !== 0,
        center: bounds.center,
        size: bounds.size,
      }, `cmp-box-collider-${componentId}`);

      reporter.low(
        'POLYGON_COLLIDER_2D_APPROXIMATED',
        model.file,
        gameObject.name,
        'Unity PolygonCollider2D was approximated as a Cocos BoxCollider because this prefab is detected as a 3D object',
        `size=(${bounds.size.x}, ${bounds.size.y}, ${bounds.size.z}) center=(${bounds.center.x}, ${bounds.center.y}, ${bounds.center.z})`,
      );
      return;
    }

    const points = [...paths]
      .sort((left, right) => polygonPathArea(right) - polygonPathArea(left))[0] || [
        { x: -0.5, y: -0.5 },
        { x: 0.5, y: -0.5 },
        { x: 0.5, y: 0.5 },
        { x: -0.5, y: 0.5 },
      ];

    builder.addPolygonCollider2D(nodeId, componentId, {
      enabled: Number(getField(doc, 'm_Enabled', 1) || 0) !== 0,
      sensor: Number(getField(doc, 'm_IsTrigger', 0) || 0) !== 0,
      offset: {
        x: finiteNumber(offset?.x, 0),
        y: finiteNumber(offset?.y, 0),
      },
      points,
    }, `cmp-polygon-collider-2d-${componentId}`);
  }

  return {
    unityRigidBody2DTypeToCocosType,
    emitRigidbody2D,
    emitCircleCollider2D,
    emitBoxCollider2D,
    polygonPathArea,
    emitPolygonCollider2D,
  };
};
