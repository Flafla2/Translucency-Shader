using UnityEngine;
using UnityEngine.Rendering;
using System.Collections;
using System.Collections.Generic;

public class CustomLightSystem
{
    static CustomLightSystem m_Instance;
    static public CustomLightSystem instance
    {
        get
        {
            if (m_Instance == null)
                m_Instance = new CustomLightSystem();
            return m_Instance;
        }
    }

    internal HashSet<TranslucentScaledLight> m_Lights = new HashSet<TranslucentScaledLight>();

    public void Add(TranslucentScaledLight o)
    {
        Remove(o);
        m_Lights.Add(o);
    }
    public void Remove(TranslucentScaledLight o)
    {
        m_Lights.Remove(o);
    }
}

[ExecuteInEditMode]
public class TranslucentScaledLightRenderer : MonoBehaviour {

    public Shader m_LightShader;
    private Material m_LightMaterial;

    public Mesh m_SphereMesh;

    private CommandBuffer m_CommandBuffer;

    private Dictionary<Camera, CommandBuffer> m_Cameras = new Dictionary<Camera,CommandBuffer>();

    public void OnDisable()
    {
        foreach (var cam in m_Cameras)
        {
            if (cam.Key)
                cam.Key.RemoveCommandBuffer(CameraEvent.AfterLighting, cam.Value);
        }
        Object.DestroyImmediate(m_LightMaterial);
    }

    public void OnWillRenderObject()
    {
        var act = gameObject.activeInHierarchy && enabled;
        if (!act)
        {
            OnDisable();
            return;
        }

        var cam = Camera.current;
        if (!cam)
            return;

        // create material used to render lights
        if (!m_LightMaterial)
        {
            m_LightMaterial = new Material(m_LightShader);
            m_LightMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        CommandBuffer buf;
        if (m_Cameras.ContainsKey(cam))
        {
            // use existing command buffers: clear them
            buf = m_Cameras[cam];
            buf.Clear();
        }
        else
        {
            // create new command buffers
            buf = new CommandBuffer();
            buf.name = "Deferred Translucent Scaled Light";
            m_Cameras[cam] = buf;

            cam.AddCommandBuffer(CameraEvent.AfterLighting, buf);
        }

        //@TODO: in a real system should cull lights, and possibly only
        // recreate the command buffer when something has changed.

        var system = CustomLightSystem.instance;

        var propColor = Shader.PropertyToID("_CustomLightColor");
        var propParams = Shader.PropertyToID("_LightParams");
        Vector4 param = Vector4.zero;
        Matrix4x4 trs = Matrix4x4.identity;

        // construct command buffer to draw lights and compute illumination on the scene
        foreach (var o in system.m_Lights)
        {
            // light parameters we'll use in the shader
            param.x = o.m_TranslucentScale;
            param.z = 1.0f / (o.m_Range * o.m_Range);

            buf.SetGlobalVector(propParams, param);
            buf.SetGlobalColor(propColor, o.GetLinearColor());

            // draw sphere that covers light area, with shader
            // pass that computes illumination on the scene
            trs = Matrix4x4.TRS(o.transform.position, o.transform.rotation, new Vector3(o.m_Range * 2, o.m_Range * 2, o.m_Range * 2));
            buf.DrawMesh(m_SphereMesh, trs, m_LightMaterial, 0, 0);
            //if (Camera.current.hdr) buf.DrawMesh(m_SphereMesh, trs, m_LightMaterial, 0, 1);
        }
    }

}
