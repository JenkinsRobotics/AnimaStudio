Shader "CodexBench/VertexColor" {
  Properties {
    _Roughness ("Roughness", Range(0,1)) = 0.5
    _Metallic ("Metallic", Range(0,1)) = 0.0
    _Selected ("Selected", Range(0,1)) = 0.0
    _SelectionColor ("Selection", Color) = (1,.48,0,1)
    _KeyColor ("Key", Color) = (1,1,1,1)
    _FillColor ("Fill", Color) = (.75,.82,1,1)
    _RimColor ("Rim", Color) = (1,1,1,1)
  }
  SubShader {
    Tags { "RenderType"="Opaque" }
    Pass {
      CGPROGRAM
      #pragma vertex vert
      #pragma fragment frag
      #include "UnityCG.cginc"
      struct appdata { float4 vertex:POSITION; float3 normal:NORMAL; float4 color:COLOR; };
      struct v2f { float4 vertex:SV_POSITION; float3 normal:TEXCOORD0; float3 world:TEXCOORD1; float4 color:COLOR; };
      float _Roughness, _Metallic, _Selected;
      float4 _SelectionColor, _KeyColor, _FillColor, _RimColor;
      v2f vert(appdata value) {
        v2f output;
        output.vertex=UnityObjectToClipPos(value.vertex);
        output.normal=UnityObjectToWorldNormal(value.normal);
        output.world=mul(unity_ObjectToWorld,value.vertex).xyz;
        output.color=value.color;
        return output;
      }
      fixed4 frag(v2f value):SV_Target {
        float3 n=normalize(value.normal);
        float3 view=normalize(_WorldSpaceCameraPos-value.world);
        float key=max(dot(n,normalize(float3(.5,.9,.6))),0);
        float fill=max(dot(n,normalize(float3(-.7,.3,.4))),0);
        float rim=pow(1-max(dot(n,view),0),3);
        float3 base=lerp(value.color.rgb,_SelectionColor.rgb,_Selected*.38);
        float3 lit=base*(.22+_KeyColor.rgb*key*.75+_FillColor.rgb*fill*.28);
        float3 spec=lerp(1,base,_Metallic)*pow(max(dot(n,normalize(float3(.5,.9,.6)+view)),0),lerp(96,8,_Roughness))*(1-_Roughness)*.4;
        return fixed4(lit+spec+_RimColor.rgb*rim*.18,value.color.a);
      }
      ENDCG
    }
  }
}
