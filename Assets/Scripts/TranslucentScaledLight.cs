using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class TranslucentScaledLight : MonoBehaviour
{

    public Color m_Color = Color.white;
    public float m_TranslucentScale = 1.0f;
    public float m_Intensity = 1.0f;
    public float m_Range = 10.0f;

    public void OnEnable()
    {
        CustomLightSystem.instance.Add(this);
    }

    public void Start()
    {
        CustomLightSystem.instance.Add(this);
    }

    public void OnDisable()
    {
        CustomLightSystem.instance.Remove(this);
    }

    public Color GetLinearColor()
    {
        return new Color(
            Mathf.GammaToLinearSpace(m_Color.r * m_Intensity),
            Mathf.GammaToLinearSpace(m_Color.g * m_Intensity),
            Mathf.GammaToLinearSpace(m_Color.b * m_Intensity),
            1.0f
        );
    }

    public void OnDrawGizmos()
    {
        Gizmos.DrawIcon(transform.position, "PointLight Gizmo", true);
    }
    public void OnDrawGizmosSelected()
    {
        Gizmos.color = new Color(0.1f, 0.7f, 1.0f, 0.6f);

        Gizmos.matrix = Matrix4x4.identity;
        Gizmos.DrawWireSphere(transform.position, m_Range);
    }
}