shader_type canvas_item;

const int MaterialHalfBytes = 2;
struct RayTracingMaterial {
	vec4 color;
	vec3 emissionColor;
	float emissionStrength;
};

const int SphereHalfBytes = 1 + MaterialHalfBytes;
struct Sphere {
	vec3 position;
	float radius;
	RayTracingMaterial material;
};

const int TriangleHalfBytes = 6;
struct Triangle {
	vec3 posA, posB, posC;
	vec3 normalA, normalB, normalC;
};

const int MeshInfoHalfBytes = 2 + MaterialHalfBytes;
struct MeshInfo {
	vec3 boundsMin;
	float firstTriangleIndex;
	vec3 boundsMax;
	float numTriangles;
	RayTracingMaterial material;
};

struct Ray {
	vec3 dir;
	vec3 origin;
};

struct HitInfo {
	bool didHit;
	float dst;
	vec3 hitPoint;
	vec3 normal;
	RayTracingMaterial material;
};

const float INF = 10E6;

uniform vec3 viewParams;
uniform mat4 localToWorldMatrix;

uniform uint Frame;

uniform int MaxBounceCount;
uniform int NumRaysPerPixel;

uniform sampler2D Triangles;
uniform sampler2D AllMeshInfo;
uniform int NumMeshes;

uniform sampler2D Spheres;
uniform int NumSpheres;

float RandomValue(inout uint state) {
	state = state * 747796405u + 2891336453u;
	uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	result = (result >> 22u) ^ result;
	return float(result) / 4294967295.0;
}

float RandomValueNormalDistribution(inout uint state) {
	float theta = 2.0 * PI * RandomValue(state);
	float rho = sqrt(-2.0 * log(RandomValue(state)));
	return rho * cos(theta);
}

vec3 RandomDirection(inout uint state) {
	float x = RandomValueNormalDistribution(state);
	float y = RandomValueNormalDistribution(state);
	float z = RandomValueNormalDistribution(state);
	return normalize(vec3(x, y, z));
}

vec3 RandomHemisphereDirection(vec3 normal, inout uint rngState) {
	vec3 dir = RandomDirection(rngState);
	return dir * sign(dot(normal, dir));
}

Sphere FetchSphere(int index) {
	vec4[SphereHalfBytes] data;
	for (int b = 0; b < SphereHalfBytes; b++) {
		data[b] = texelFetch(Spheres, ivec2(b, index), 0);
	}
	Sphere sphere = Sphere(data[0].xyz, data[0].w, RayTracingMaterial(data[1], data[2].rgb, data[2].a));
	return sphere;
}

MeshInfo FetchMeshInfo(int index) {
	vec4[MeshInfoHalfBytes] data;
	for (int b = 0; b < MeshInfoHalfBytes; b++) {
		data[b] = texelFetch(AllMeshInfo, ivec2(b, index), 0);
	}
	MeshInfo meshInfo = MeshInfo(data[0].xyz, data[0].w, data[1].xyz, data[1].w, RayTracingMaterial(data[2], data[3].rgb, data[3].a));
	return meshInfo;
}

Triangle FetchTriangle(int index) {
	vec4[TriangleHalfBytes] data;
	for (int b = 0; b < TriangleHalfBytes; b++) {
		data[b] = texelFetch(Triangles, ivec2(b, index), 0);
	}
	Triangle triangle = Triangle(data[0].xyz, data[1].xyz, data[2].xyz, data[3].xyz, data[4].xyz, data[5].xyz);
	return triangle;
}

vec3 GetEnvironmentLight(Ray ray) {
	return vec3(0);
}

bool RayBoundingBox(Ray ray, vec3 boxMin, vec3 boxMax) {
	vec3 invDir = 1.0 / ray.dir;
	vec3 tMin = (boxMin - ray.origin) * invDir;
	vec3 tMax= (boxMax - ray.origin) * invDir;
	vec3 t1 = min(tMin, tMax);
	vec3 t2 = max(tMin, tMax);
	float tNear = max(max(t1.x, t1.y), t1.z);
	float tFar = min(min(t2.x, t2.y), t2.z);
	return tNear <= tFar;
}

HitInfo RayTriangle(Ray ray, Triangle tri) {
	vec3 edgeAB = tri.posC - tri.posA;
	vec3 edgeAC = tri.posB - tri.posA;
	vec3 normalVector = cross(edgeAB, edgeAC);
	vec3 ao = ray.origin - tri.posA;
	vec3 dao = cross(ao, ray.dir);

	float deter = -dot(ray.dir, normalVector);
	float invDet = 1.0 / deter;

	float dst = dot(ao, normalVector) * invDet;
	float u = dot(edgeAC, dao) * invDet;
	float v = -dot(edgeAB, dao) * invDet;
	float w = 1.0 - u - v;

	HitInfo hitInfo;
	hitInfo.didHit = deter >= 1E-6 && dst >= 0.0 && u >= 0.0 && v >= 0.0 && w >= 0.0;
	hitInfo.hitPoint = ray.origin + ray.dir * dst;
	hitInfo.normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
	hitInfo.dst = dst;
	return hitInfo;
}

HitInfo RaySphere(Ray ray, vec3 sphereCenter, float sphereRadius) {
	HitInfo hitInfo;
	hitInfo.didHit = false;
	hitInfo.dst = INF;
	vec3 offsetRayOrigin = ray.origin - sphereCenter;

	float a = dot(ray.dir, ray.dir);
	float b = 2.0 * dot(offsetRayOrigin, ray.dir);
	float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;

	float discriminant = b * b - 4.0 * a * c;

	if (discriminant >= 0.0) {
		float dst = (-b - sqrt(discriminant)) / (2.0 * a);

		if (dst >= 0.0) {
			hitInfo.didHit = true;
			hitInfo.dst = dst;
			hitInfo.hitPoint = ray.origin + ray.dir * dst;
			hitInfo.normal = normalize(hitInfo.hitPoint - sphereCenter);
		}
	}
	return hitInfo;
}

HitInfo CalculateRayCollision(Ray ray) {
	HitInfo closestHit;
	closestHit.didHit = false;
	closestHit.dst = INF;
	closestHit.material = RayTracingMaterial(vec4(0,0,0,1.0), vec3(0), 0.0);

	for (int i = 0; i < NumSpheres; i++) {
		Sphere sphere = FetchSphere(i);
		HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);

		if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
			closestHit = hitInfo;
			closestHit.material = sphere.material;
		}
	}

	for (int meshIndex = 0; meshIndex < NumMeshes; meshIndex++) {
		MeshInfo meshInfo = FetchMeshInfo(meshIndex);

		if (!RayBoundingBox(ray, meshInfo.boundsMin, meshInfo.boundsMax)) {
			continue;
		}

		for (int i = 0; i < int(meshInfo.numTriangles); i++) {
			int triIndex = int(meshInfo.firstTriangleIndex) + i;
			Triangle tri = FetchTriangle(triIndex);
			HitInfo hitInfo = RayTriangle(ray, tri);

			if (hitInfo.didHit && hitInfo.dst < closestHit.dst) {
				closestHit = hitInfo;
				closestHit.material = meshInfo.material;
			}
		}
	}

	return closestHit;
}

vec3 Trace(Ray ray, inout uint rngState) {
	vec3 incomingLight = vec3(0);
	vec3 rayColor = vec3(1);

	for (int i = 0; i <= MaxBounceCount; i++) {
		HitInfo hitInfo = CalculateRayCollision(ray);
		if (hitInfo.didHit) {
			ray.origin = hitInfo.hitPoint;
			ray.dir = normalize(hitInfo.normal + RandomDirection(rngState));

			RayTracingMaterial material = hitInfo.material;
			vec3 emittedLight = material.emissionColor * material.emissionStrength;
			incomingLight += emittedLight * rayColor;
			rayColor *= material.color.rgb;
		}
		else {
			//incomingLight += GetEnvironmentLight(ray) * rayColor;
			break;
		}
	}

	return incomingLight;
}

void fragment() {
	vec2 numPixels = viewParams.xy/100.0;
	vec2 pixelCoord = UV * numPixels;
	uint pixelIndex = uint(pixelCoord.y * numPixels.x + pixelCoord.x);
	uint rngState = pixelIndex + Frame * 719393u;

	vec3 viewPointLocal = vec3(UV.x - 0.5, 0.5 - UV.y, -1) * viewParams;
	vec3 viewPoint = (localToWorldMatrix * vec4(viewPointLocal, 0)).xyz;

	Ray ray;
	ray.origin = localToWorldMatrix[3].xyz;
	ray.dir = normalize(viewPoint - ray.origin);

	vec3 totalIncomingLight = vec3(0);

	for (int rayIndex = 0; rayIndex < NumRaysPerPixel; rayIndex++) {
		totalIncomingLight += Trace(ray, rngState);
	}

	vec3 pixelCol = totalIncomingLight / float(NumRaysPerPixel);
	COLOR = vec4(pixelCol, 1.0);
}