using UnityEngine;
using System.Collections.Generic;

public static class MeshDrawer
{
    struct Drawer
    {
        public Transform transform;
        public MeshFilter meshFilter;
        public MeshRenderer renderer;
        public MaterialPropertyBlock properties;

        public Drawer(
            Transform transform,
            MeshFilter filter,
            MeshRenderer renderer
        )
        {
            this.transform = transform;
            this.meshFilter = filter;
            this.renderer = renderer;
            this.properties = new MaterialPropertyBlock();
        }
    }

    static List<Drawer> _drawerPool;
    static int _drawerUsedCount;
    static int _lastFrameCount;

    public static void DrawWithVelocity(
        Mesh mesh,
        Vector3 translation, Quaternion rotation, Vector3 scale,
        Vector3 velocity, Vector3 angularVelocity,
        Material material
    )
    {
        var deltaRotation = Quaternion.Euler(
            angularVelocity * -Time.deltaTime
        );

        var previousMatrix = Matrix4x4.TRS(
            translation - velocity * Time.deltaTime,
            rotation * deltaRotation,
            scale
        );

        var drawer = GetDrawer();

        drawer.properties.SetMatrix("_PreviousM2", previousMatrix);
        drawer.renderer.SetPropertyBlock(drawer.properties);

        drawer.transform.position = translation;
        drawer.transform.rotation = rotation;
        drawer.transform.localScale = scale;

        drawer.meshFilter.sharedMesh = mesh;
        drawer.renderer.sharedMaterial = material;
        drawer.renderer.enabled = true;
    }

    static Drawer GetDrawer()
    {
        if (_drawerPool == null)
        {
            _drawerPool = new List<Drawer>();
            _lastFrameCount = Time.frameCount;
        }
        else if (_lastFrameCount != Time.frameCount)
        {
            for (var i = 0; i < _drawerUsedCount; i++)
                _drawerPool[i].renderer.enabled = false;
            _drawerUsedCount = 0;
            _lastFrameCount = Time.frameCount;
        }

        if (_drawerUsedCount < _drawerPool.Count)
        {
            return _drawerPool[_drawerUsedCount++];
        }
        else
        {
            AppendNewDrawerToPool();
            return _drawerPool[_drawerUsedCount++];
        }
    }

    static void AppendNewDrawerToPool()
    {
        var go = new GameObject();
        var filter = go.AddComponent<MeshFilter>();
        var renderer = go.AddComponent<MeshRenderer>();
        _drawerPool.Add(new Drawer(go.transform, filter, renderer));
    }
}
