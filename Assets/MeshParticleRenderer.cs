using UnityEngine;
using UnityEngine.Rendering;
using System.Collections;

public class MeshParticleRenderer : MonoBehaviour
{
    [SerializeField] Mesh _mesh;
    [SerializeField] Material _material;

    ParticleSystem _master;
    ParticleSystem.Particle[] _particles;
    int _particleCount;

    void OnEnable()
    {
        _master = GetComponent<ParticleSystem>();
        _particles = new ParticleSystem.Particle[_master.maxParticles];

    }

    void OnDisable()
    {
        _master = null;
        _particles = null;
    }

    void LateUpdate()
    {
        Camera.main.depthTextureMode |=
            DepthTextureMode.Depth | DepthTextureMode.MotionVectors;

        _particleCount = _master.GetParticles(_particles);

        for (var i = 0; i < _particleCount; i++)
        {
            var t = _particles[i].position;
            var r = Quaternion.Euler(_particles[i].rotation3D);
            var s = _particles[i].GetCurrentSize3D(_master);

            var vt = _particles[i].velocity;
            var vr = _particles[i].angularVelocity3D;

            MeshDrawer.DrawWithVelocity(
                _mesh, t, r, s, vt, vr, _material
            );
        }
    }
}
