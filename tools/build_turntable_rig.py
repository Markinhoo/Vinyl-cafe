"""Split the textured Meshy asset using the supplied segmented mesh (requires numpy).

Original GLBs are never modified. The generated rig retains original coordinates,
UVs, normals and textures; only the arm's vertices are made pivot-relative.
"""
import copy
import itertools
import json
import struct
from pathlib import Path
import numpy as np

MODELS = Path(__file__).resolve().parents[1] / 'assets/models'

def read_glb(path):
    with path.open('rb') as f:
        f.read(12)
        length, _ = struct.unpack('<II', f.read(8))
        doc = json.loads(f.read(length))
        length, _ = struct.unpack('<II', f.read(8))
        binary = f.read(length)
    return doc, binary

def read_accessor(doc, binary, index):
    a = doc['accessors'][index]
    v = doc['bufferViews'][a['bufferView']]
    dtype = {5126:'<f4', 5125:'<u4', 5123:'<u2', 5122:'<i2', 5121:'u1'}[a['componentType']]
    count = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4}[a['type']]
    width = np.dtype(dtype).itemsize
    offset = a.get('byteOffset', 0) + v.get('byteOffset', 0)
    return np.ndarray((a['count'], count), dtype=dtype, buffer=binary, offset=offset,
                      strides=(v.get('byteStride', width*count), width)).copy()

def keys(points):
    points = points.astype(np.int64)
    return (points[:,0]<<28)+(points[:,1]<<14)+points[:,2]

def build():
    source, binary = read_glb(MODELS / 'audio_technica_turntable_textured.glb')
    segments, segment_binary = read_glb(MODELS / 'audio_technica_turntable_segmented.glb')
    primitive = source['meshes'][0]['primitives'][0]
    attributes = {name:read_accessor(source,binary,index) for name,index in primitive['attributes'].items()}
    positions = attributes['POSITION']
    minimum = positions.min(0)
    step = float((positions.max(0)[0]-minimum[0])/16383)
    quantized = np.rint((positions-minimum)/step).astype(np.int64)
    refs = [read_accessor(segments,segment_binary,m['primitives'][0]['attributes']['POSITION']) for m in segments['meshes']]
    ref_keys = keys(np.concatenate(refs))
    ref_labels = np.concatenate([np.full(len(p),i,dtype=np.uint8) for i,p in enumerate(refs)])
    order = np.argsort(ref_keys)
    ref_keys, ref_labels = ref_keys[order], ref_labels[order]
    labels = np.full(len(positions),255,dtype=np.uint8)
    # The two exports differ by <= one quantization unit at a few vertices.
    offsets = sorted(itertools.product((-1,0,1),repeat=3),key=lambda p:sum(x*x for x in p))
    for offset in offsets:
        missing = np.flatnonzero(labels==255)
        if not len(missing):
            break
        query = keys(quantized[missing]+offset)
        index = np.minimum(np.searchsorted(ref_keys,query),len(ref_keys)-1)
        found = ref_keys[index]==query
        labels[missing[found]] = ref_labels[index[found]]
    coverage = float(np.mean(labels!=255))
    print(f'Segment correspondence: {coverage:.6%}',flush=True)
    if coverage < .99:
        raise RuntimeError('Segment registration does not match the textured asset.')
    # Segmentation omits some disconnected faces. Resolve unknown points near
    # the arm by their nearest segmented reference, leaving the rest stationary.
    missing = np.flatnonzero(labels==255)
    arm_min, arm_max = refs[3].min(0)-2, refs[3].max(0)+2
    near_arm = np.all((quantized[missing]>=arm_min)&(quantized[missing]<=arm_max),axis=1)
    labels[missing] = 0
    candidates = missing[near_arm]
    samples=np.concatenate([p[::16] for p in refs]).astype(np.float64)
    sample_labels=np.concatenate([np.full(len(p[::16]),i,dtype=np.uint8) for i,p in enumerate(refs)])
    norm=np.sum(samples*samples,axis=1)
    for offset in range(0,len(candidates),64):
        selected=candidates[offset:offset+64]
        query=quantized[selected].astype(np.float64)
        distances=np.sum(query*query,axis=1)[:,None]+norm[None,:]-2*(query@samples.T)
        labels[selected]=sample_labels[np.argmin(distances,axis=1)]
    print('Nearest-reference arm candidates:',len(candidates),flush=True)
    triangles = read_accessor(source,binary,primitive['indices']).reshape(-1,3)
    arm_triangles = (labels[triangles]==3).sum(axis=1)>=2
    pivot = minimum + np.array([13450,3066,6000],dtype=np.float32)*step
    doc = {'asset':{'version':'2.0','generator':'Vinyl Cafe segmented turntable rig'},
           'scene':0,'scenes':[{'nodes':[0]}],
           'nodes':[{'name':'TurntableRig','children':[1,2]},
                    {'name':'Chassis','mesh':0},
                    {'name':'TonearmPivot','translation':pivot.tolist(),'children':[3]},
                    {'name':'SegmentedTonearm','mesh':1}],
           'meshes':[], 'accessors':[], 'bufferViews':[],
           'materials':copy.deepcopy(source['materials']),
           'textures':copy.deepcopy(source['textures']),
           'samplers':copy.deepcopy(source['samplers']),
           'images':[{'uri':f"audio_technica_turntable_textured_{i['name']}.jpg"} for i in source['images']]}
    chunks = bytearray()
    def append_array(array, type_name, component_type, bounds=False):
        while len(chunks)%4:
            chunks.append(0)
        offset = len(chunks)
        raw = array.tobytes()
        chunks.extend(raw)
        view = len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(raw)})
        acc = {'bufferView':view,'componentType':component_type,'count':len(array),'type':type_name}
        if bounds:
            acc['min']=array.min(0).tolist(); acc['max']=array.max(0).tolist()
        doc['accessors'].append(acc)
        return len(doc['accessors'])-1
    for mesh_id, mask in enumerate((~arm_triangles,arm_triangles)):
        selected = triangles[mask]
        used, remap = np.unique(selected,return_inverse=True)
        attrs = {}
        for name, values in attributes.items():
            values = values[used].copy()
            if mesh_id==1 and name=='POSITION':
                values -= pivot
            attrs[name]=append_array(values, f'VEC{values.shape[1]}',5126,name=='POSITION')
        indices = append_array(remap.reshape(-1).astype('<u4'),'SCALAR',5125)
        doc['meshes'].append({'name':('Chassis','SegmentedTonearm')[mesh_id],
                              'primitives':[{'attributes':attrs,'indices':indices,'material':0}]})
        print(f'Mesh {mesh_id}: {len(used)} vertices, {len(selected)} triangles',flush=True)
    while len(chunks)%4:
        chunks.append(0)
    doc['buffers']=[{'byteLength':len(chunks)}]
    encoded=json.dumps(doc,separators=(',',':')).encode()
    encoded += b' '*((-len(encoded))%4)
    output=MODELS/'turntable_rigged_v2.glb'
    with output.open('wb') as f:
        f.write(struct.pack('<4sII',b'glTF',2,12+8+len(encoded)+8+len(chunks)))
        f.write(struct.pack('<II',len(encoded),0x4E4F534A)); f.write(encoded)
        f.write(struct.pack('<II',len(chunks),0x004E4942)); f.write(chunks)
    print('Pivot:',pivot.tolist(),'Output:',output,flush=True)
    return positions,attributes,labels

if __name__=='__main__':
    build()
