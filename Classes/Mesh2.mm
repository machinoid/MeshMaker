//
//  Mesh2.cpp
//  OpenGLEditor
//
//  Created by Filip Kunc on 19.06.11.
//  For license see LICENSE.TXT
//

#import "Mesh2.h"
#import <osd/mutex.h>
#import <osd/vertex.h>
#import <osd/mesh.h>
#import <osd/cpuDispatcher.h>
#import <common/shape_utils.h>

bool Mesh2::_useSoftSelection = false;
bool Mesh2::_selectThrough = false;

NSColor *generateRandomColor();

NSColor *generateRandomColor()
{
    float hue = (random() % 10) / 10.0f;
    
    return [NSColor colorWithCalibratedHue:hue 
                                saturation:0.5f
                                brightness:0.6f 
                                    alpha:1.0f];
}

NSString *Mesh2::descriptionOfMeshType(MeshType meshType)
{
    switch (meshType)
	{
		case MeshTypeCube:
			return @"Cube";
		case MeshTypeCylinder:
			return @"Cylinder";
		case MeshTypeSphere:
			return @"Sphere";
        case MeshTypePlane:
            return @"Plane";
        case MeshTypeIcosahedron:
            return @"Icosahedron";
		default:
			return nil;
	}
}

Mesh2::Mesh2()
{
    _selectionMode = MeshSelectionModeVertices;
    
    _vboID = 0U;
    _vboGenerated = false;
    
    _texture = nil;
    _isUnwrapped = false;
    
    setColor(generateRandomColor());
}

Mesh2::Mesh2(MemoryReadStream *stream) : Mesh2()
{
    NSColor *color = nil;
    
    if (stream.version >= ModelVersionColors)
    {
        Vector4D baseColor;           
        [stream readBytes:&baseColor length:sizeof(Vector4D)];
        color = [NSColor colorWithCalibratedRed:baseColor.x green:baseColor.y blue:baseColor.z alpha:baseColor.w];
    }
    
    uint verticesSize;
    uint texCoordsSize;
    uint trianglesSize;
    
    [stream readBytes:&verticesSize length:sizeof(uint)];
    [stream readBytes:&texCoordsSize length:sizeof(uint)];
    [stream readBytes:&trianglesSize length:sizeof(uint)];
    
    vector<Vector3D> vertices;
    vector<Vector3D> texCoords;
    vector<TriQuad> triangles;
    
    for (uint i = 0; i < verticesSize; i++)
    {
        Vector3D vertex;
        [stream readBytes:&vertex length:sizeof(Vector3D)];
        vertices.push_back(vertex);
    }
    
    for (uint i = 0; i < texCoordsSize; i++)
    {
        Vector3D texCoord;
        [stream readBytes:&texCoord length:sizeof(Vector3D)];
        texCoords.push_back(texCoord);
    }
    
    if (stream.version >= ModelVersionTriQuads)
    {
        for (uint i = 0; i < trianglesSize; i++)
        {
            TriQuad triangle;
            [stream readBytes:&triangle length:sizeof(TriQuad)];
            triangles.push_back(triangle);
        }
    }
    else
    {
        for (uint i = 0; i < trianglesSize; i++)
        {
            Triangle triangle;
            [stream readBytes:&triangle length:sizeof(Triangle)];
            TriQuad triQuad;
            triQuad.isQuad = false;
            for (uint j = 0; j < 3; j++)
            {
                triQuad.vertexIndices[j] = triangle.vertexIndices[j];
                triQuad.texCoordIndices[j] = triangle.texCoordIndices[j];
            }
            triangles.push_back(triQuad);
        }
    }
    
    this->fromIndexRepresentation(vertices, texCoords, triangles);
    if (color)
        this->setColor(color);
}

void Mesh2::encode(MemoryWriteStream *stream)
{
    if (stream.version > ModelVersionColors)
    {
        Vector4D baseColor;
        baseColor.x = _color.redComponent;
        baseColor.y = _color.greenComponent;
        baseColor.z = _color.blueComponent;
        baseColor.w = _color.alphaComponent;
        [stream writeBytes:&baseColor length:sizeof(Vector4D)];
    }
    
    vector<Vector3D> vertices;
    vector<Vector3D> texCoords;
    vector<TriQuad> triangles;
    
    this->toIndexRepresentation(vertices, texCoords, triangles);
    
	uint size = vertices.size();
    [stream writeBytes:&size length:sizeof(uint)];
    size = texCoords.size();
    [stream writeBytes:&size length:sizeof(uint)];
	size = triangles.size();
    [stream writeBytes:&size length:sizeof(uint)];
    
	if (vertices.size() > 0)
        [stream writeBytes:&vertices.at(0) length:vertices.size() * sizeof(Vector3D)];
    
    if (texCoords.size() > 0)
        [stream writeBytes:&texCoords.at(0) length:texCoords.size() * sizeof(Vector3D)];
	
	if (triangles.size() > 0)
        [stream writeBytes:&triangles.at(0) length:triangles.size() * sizeof(TriQuad)];
}

void Mesh2::setColor(NSColor *color)
{
    _color = color;
    CGFloat colorComponents[4];
    [_color getComponents:colorComponents];
    for (int i = 0; i < 4; i++)
        _colorComponents[i] = (float)colorComponents[i];
    
    resetTriangleCache();    
}

Mesh2::~Mesh2()
{
    resetTriangleCache();
    _texture = nil;
}

FPTexture *Mesh2::texture()
{
    if (!_texture)
        _texture = [[FPTexture alloc] init];
    return _texture;
}

void Mesh2::resetAlgorithmData()
{
    for (VertexNode *vertexNode = _vertices.begin(), *vertexEnd = _vertices.end(); vertexNode != vertexEnd; vertexNode = vertexNode->next())
        vertexNode->algorithmData.clear();
    
    for (TexCoordNode *texCoordNode = _texCoords.begin(), *texCoordEnd = _texCoords.end(); texCoordNode != texCoordEnd; texCoordNode = texCoordNode->next())
        texCoordNode->algorithmData.clear();
}

void Mesh2::setSelectionMode(MeshSelectionMode value)
{
    resetEdgeCache();
    
    _selectionMode = value;
    _cachedVertexSelection.clear();
    _cachedTriangleSelection.clear();
    _cachedVertexEdgeSelection.clear();
    _cachedTexCoordSelection.clear();
    _cachedTexCoordEdgeSelection.clear();
    
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
        {
            for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
                _cachedVertexSelection.push_back(node);
            
            for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
                _cachedTexCoordSelection.push_back(node);            
        } break;
        case MeshSelectionModeTriangles:
        {
            for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
                node->data().selected = false;
            
            for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
                node->data().selected = false;
            
            for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
            {
                _cachedTriangleSelection.push_back(node);
                
                Triangle2 &triangle = node->data();
                if (triangle.selected)
                {
                    for (uint i = 0; i < triangle.count(); i++)
                    {
                        triangle.vertex(i)->data().selected = true;
                        triangle.texCoord(i)->data().selected = true;
                    }
                }
            }
        } break;
        case MeshSelectionModeEdges:
        {
            for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
                node->data().selected = false;
            
            for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
                node->data().selected = false;
            
            if (_isUnwrapped)
            {
                for (TexCoordEdgeNode *node = _texCoordEdges.begin(), *end = _texCoordEdges.end(); node != end; node = node->next())
                {
                    _cachedTexCoordEdgeSelection.push_back(node);
                    
                    TexCoordEdge &edge = node->data();
                    if (edge.selected)
                    {
                        for (uint i = 0; i < 2; i++)
                            edge.texCoord(i)->data().selected = true;
                    }
                }
            }
            else
            {
                for (VertexEdgeNode *node = _vertexEdges.begin(), *end = _vertexEdges.end(); node != end; node = node->next())
                {
                    _cachedVertexEdgeSelection.push_back(node);
                    
                    VertexEdge &edge = node->data();
                    if (edge.selected)
                    {
                        for (uint i = 0; i < 2; i++)
                            edge.vertex(i)->data().selected = true;
                    }
                }
            }
        } break;
        default:
            break;
    }
}

uint Mesh2::selectedCount() const
{
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
            if (_isUnwrapped)
                return _cachedTexCoordSelection.size();
            return _cachedVertexSelection.size();            
        case MeshSelectionModeTriangles:
            return _cachedTriangleSelection.size();
        case MeshSelectionModeEdges:
            if (_isUnwrapped)
                return _cachedTexCoordEdgeSelection.size();
            return _cachedVertexEdgeSelection.size();
        default:
            return 0;
    }
}

bool Mesh2::isSelectedAtIndex(uint index) const
{
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
            if (_isUnwrapped)
                return _cachedTexCoordSelection.at(index)->data().selected;
            return _cachedVertexSelection.at(index)->data().selected;
        case MeshSelectionModeTriangles:
            return _cachedTriangleSelection.at(index)->data().selected;
        case MeshSelectionModeEdges:
            if (_isUnwrapped)
                return _cachedTexCoordEdgeSelection.at(index)->data().selected;
            return _cachedVertexEdgeSelection.at(index)->data().selected;
        default:
            return false;
    }
}

void Mesh2::setSelectedAtIndex(bool selected, uint index)
{
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
            if (_isUnwrapped)
                _cachedTexCoordSelection.at(index)->data().selected = selected;
            else
                _cachedVertexSelection.at(index)->data().selected = selected;
            break;
        case MeshSelectionModeTriangles:
        {
            Triangle2 &triangle = _cachedTriangleSelection.at(index)->data();
            triangle.selected = selected;
            for (uint i = 0; i < triangle.count(); i++)
            {
                triangle.vertex(i)->data().selected = selected;
                triangle.texCoord(i)->data().selected = selected;
            }                
        } break;
        case MeshSelectionModeEdges:
        {
            if (_isUnwrapped)
            {
                TexCoordEdge &edge = _cachedTexCoordEdgeSelection.at(index)->data();
                edge.selected = selected;
                for (uint i = 0; i < 2; i++)
                    edge.texCoord(i)->data().selected = selected;
            }
            else                
            {
                VertexEdge &edge = _cachedVertexEdgeSelection.at(index)->data();
                edge.selected = selected;
                for (uint i = 0; i < 2; i++)
                    edge.vertex(i)->data().selected = selected;
            }
        } break;
        default:
            break;
    }
}

void Mesh2::expandSelectionFromIndex(uint index, bool invert)
{
    switch (_selectionMode)
    {
        case MeshSelectionModeEdges:
        {
            VertexEdge &edge = _cachedVertexEdgeSelection.at(index)->data();

            if (invert)
                edge.selectEdgesInQuadLoop();
            else
                edge.selectEdgesInEdgeLoop();
            
            setSelectionMode(_selectionMode);
        } break;
        default:
            break;
    }
}

void Mesh2::getSelectionCenterRotationScale(Vector3D &center, Quaternion &rotation, Vector3D &scale)
{
    center = Vector3D();
	rotation = Quaternion();
	scale = Vector3D(1, 1, 1);
    
	uint selectedCount = 0;
    
    if (_isUnwrapped)
    {
        for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
        {
            if (node->data().selected)
            {
                center += node->data().position;
                selectedCount++;
            }
        }
    }
    else
    {
        for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
        {
            if (node->data().selected)
            {
                center += node->data().position;
                selectedCount++;
            }
        }        
    }
	if (selectedCount > 0)
		center /= (float)selectedCount;
}

void Mesh2::transformAll(const Matrix4x4 &matrix)
{
    resetTriangleCache();
    
    if (_isUnwrapped)
    {
        for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
        {
            Vector3D &v = node->data().position;
            v = matrix.Transform(v);
        }
    }
    else
    {
        for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
        {
            Vector3D &v = node->data().position;
            v = matrix.Transform(v);
        }
    }
    
    setSelectionMode(_selectionMode);
}

void Mesh2::transformSelected(const Matrix4x4 &matrix)
{
    resetTriangleCache();
    
    if (_isUnwrapped)
    {
        for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
        {
            if (node->data().selected)
            {
                Vector3D &v = node->data().position;
                v = matrix.Transform(v);
            }
        }
    }
    else
    {
        for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
        {
            if (node->data().selected)
            {
                Vector3D &v = node->data().position;
                v = matrix.Transform(v);
            }
            else if (_useSoftSelection && node->selectionWeight > 0.1f)
            {
                Vector3D &v = node->data().position;
                v = v.Lerp(matrix.Transform(v), node->selectionWeight);            
            }
        }
    }
}

void Mesh2::fastMergeSelectedVertices()
{
    Vector3D center = Vector3D();
    
    SimpleList<VertexNode *> selectedNodes;
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (node->data().selected)
        {
            selectedNodes.add(node);
            center += node->data().position;
        }
    }
    
    if (selectedNodes.count() < 2)
        return;
    
    center /= (float)selectedNodes.count();
    
    VertexNode *centerNode = _vertices.add(center);
    
    for (SimpleNode<VertexNode *> *node = selectedNodes.begin(), *end = selectedNodes.end(); node != end; node = node->next())
    {
        node->data()->replaceVertex(centerNode);        
    }    
}

void Mesh2::fastMergeSelectedTexCoords()
{
    Vector3D center = Vector3D();
    
    SimpleList<TexCoordNode *> selectedNodes;
    
    for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
    {
        if (node->data().selected)
        {
            selectedNodes.add(node);
            center += node->data().position;
        }
    }
    
    if (selectedNodes.count() < 2)
        return;
    
    center /= (float)selectedNodes.count();
    
    TexCoordNode *centerNode = _texCoords.add(center);
    
    for (SimpleNode<TexCoordNode *> *node = selectedNodes.begin(), *end = selectedNodes.end(); node != end; node = node->next())
    {
        node->data()->replaceVertex(centerNode);
    }
}

void Mesh2::removeDegeneratedTriangles()
{
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        if (node->data().isDegeneratedAfterCollapseToTriangle())
            _triangles.remove(node);
    }
}

void Mesh2::removeNonUsedVertices()
{
    resetTriangleCache();
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (!node->isUsed())
            _vertices.remove(node);
    }
}

void Mesh2::removeNonUsedTexCoords()
{
    resetTriangleCache();
    
    for (TexCoordNode *node = _texCoords.begin(), *end = _texCoords.end(); node != end; node = node->next())
    {
        if (!node->isUsed())
            _texCoords.remove(node);
    }
}

void Mesh2::mergeSelectedVertices()
{
    resetTriangleCache();
    
    if (_isUnwrapped)
        fastMergeSelectedTexCoords();
    else
        fastMergeSelectedVertices();
    
    removeDegeneratedTriangles();
    removeNonUsedVertices();
    removeNonUsedTexCoords();
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::removeSelectedVertices()
{
    resetTriangleCache();
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (node->data().selected)
            _vertices.remove(node);
    }
    
    removeDegeneratedTriangles();
    removeNonUsedVertices();
    removeNonUsedTexCoords();
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::removeSelectedTriangles()
{
    resetTriangleCache();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        if (node->data().selected)
            _triangles.remove(node);
    }
    
    removeNonUsedVertices();
    removeNonUsedTexCoords();
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::removeSelectedEdges()
{
    resetTriangleCache();
    
    for (VertexEdgeNode *node = _vertexEdges.begin(), *end = _vertexEdges.end(); node != end; node = node->next())
    {
        if (node->data().selected)
            _vertexEdges.remove(node);
    }
    
    removeDegeneratedTriangles();
    removeNonUsedVertices();
    removeNonUsedTexCoords();

    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::removeSelected()
{
    switch (_selectionMode)
    {
        case MeshSelectionModeTriangles:
            removeSelectedTriangles();
            break;
        case MeshSelectionModeVertices:
            removeSelectedVertices();
            break;
        case MeshSelectionModeEdges:
            removeSelectedEdges();
            break;
        default:
            break;
    }    
}

void Mesh2::mergeSelected()
{
    switch (_selectionMode)
	{
		case MeshSelectionModeVertices:
			mergeSelectedVertices();
			break;
		default:
			break;
	}
}

void Mesh2::triangulate()
{
    resetTriangleCache();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        Triangle2 quad = node->data();
        if (quad.isQuad())
        {
            Triangle2 triangle[2];
            
            uint v = 0;
            for (uint i = 0; i < 2; i++)
            {
                for (uint j = 0; j < 3; j++)
                {
                    uint index = Triangle2::twoTriIndices[v];
                    v++;
                    triangle[i].setVertex(j, quad.vertex(index));
                    triangle[i].setTexCoord(j, quad.texCoord(index));
                }
                
                _triangles.add(triangle[i]);
            }
            
            _triangles.remove(node);
        }
    }
    
    makeEdges();
	
    setSelectionMode(_selectionMode);
}

void Mesh2::openSubdivision()
{
    OpenSubdiv::OsdCpuKernelDispatcher::Register();
    
    Scheme scheme = kCatmark;
    
    if (scheme == kLoop)
        triangulate();
    
    vector<Vector3D> vertices;
    vector<Vector3D> texCoords;
    vector<TriQuad> triQuads;
    toIndexRepresentation(vertices, texCoords, triQuads);
    
    vector<float> verts;
    vector<int> faceverts;
    vector<int> nvertsPerFace;
    
    for (uint i = 0; i < vertices.size(); i++)
    {
        verts.push_back(vertices[i].x);
        verts.push_back(vertices[i].y);
        verts.push_back(vertices[i].z);
    }
    
    for (uint i = 0; i < triQuads.size(); i++)
    {
        uint nvertsPerCurrentFace = triQuads[i].isQuad ? 4 : 3;
        nvertsPerFace.push_back(nvertsPerCurrentFace);
        for (uint j = 0; j < nvertsPerCurrentFace; j++)
            faceverts.push_back(triQuads[i].vertexIndices[j]);
    }
    
    OpenSubdiv::OsdHbrMesh *hbrMesh = simpleHbr2<OpenSubdiv::OsdVertex>(verts, faceverts, nvertsPerFace, scheme);
    
    OpenSubdiv::OsdMesh * osdMesh = new OpenSubdiv::OsdMesh();
    
    int level = 1;
    int kernel = OpenSubdiv::OsdKernelDispatcher::kCPU;
    
    osdMesh->Create(hbrMesh, level, kernel);
    
    delete hbrMesh;
    
    const std::vector<int> &indices = osdMesh->GetFarMesh()->GetFaceVertices(level);
    
    int nverts = (int)verts.size() / 3;
    
    std::vector<float> vertex;
    vertex.reserve(nverts * 3);
    
    const float *p = &verts[0];
    
    for (int i = 0; i < nverts; ++i)
    {
        vertex.push_back(p[0]);
        vertex.push_back(p[1]);
        vertex.push_back(p[2]);
        p += 3;
    }
    
    OpenSubdiv::OsdCpuVertexBuffer *osdVertexBuffer = (OpenSubdiv::OsdCpuVertexBuffer *)osdMesh->InitializeVertexBuffer(3);
    
    osdVertexBuffer->UpdateData(&vertex[0], nverts);
    
    osdMesh->Subdivide(osdVertexBuffer, NULL);
    osdMesh->Synchronize();
    
    const float *cpuBuffer = osdVertexBuffer->GetCpuBuffer();
    
    uint numVerts = scheme == kLoop ? 3 : 4;
    
    vertices.clear();
    texCoords.clear();
    triQuads.clear();
    
    int vertexCount = osdVertexBuffer->VboSize() / osdVertexBuffer->GetNumElements();
    const float *vPos = cpuBuffer;
    
    for (int i = 0; i < vertexCount; i++)
    {
        Vector3D v;
        for (uint k = 0; k < 3; k++)
        {
            v[k] = *vPos;
            vPos++;
        }
        
        vertices.push_back(v);
        texCoords.push_back(v);
    }
    
    for (uint i = 0; i < indices.size(); i += numVerts)
    {
        TriQuad triQuad;
        triQuad.isQuad = numVerts == 4;
        for (uint j = 0; j < numVerts; j++)
        {
            triQuad.vertexIndices[j] = indices[i + j];
            triQuad.texCoordIndices[j] = indices[i + j];
        }
        triQuads.push_back(triQuad);
    }
    
    delete osdVertexBuffer;
    delete osdMesh;
    
    fromIndexRepresentation(vertices, texCoords, triQuads);
    
    removeDegeneratedTriangles();
    removeNonUsedVertices();
    
    makeTexCoords();
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::detachSelectedVertices()
{
    resetTriangleCache();
    
    if (_isUnwrapped)
    {
        for (TexCoordNode *texCoordNode = _texCoords.begin(), *texCoordEnd = _texCoords.end(); texCoordNode != texCoordEnd; texCoordNode = texCoordNode->next())
        {
            if (!texCoordNode->data().selected)
                continue;
            
            texCoordNode->data().selected = false;
            
            for (SimpleNode<TriangleNode *> 
                 *triangleNode = texCoordNode->_triangles.begin(), 
                 *triangleEnd = texCoordNode->_triangles.end(); 
                 triangleNode != triangleEnd; 
                 triangleNode = triangleNode->next())
            {
                triangleNode->data()->replaceTexCoord(texCoordNode, _texCoords.add(texCoordNode->data()));
            }
            
            _texCoords.remove(texCoordNode);
        }
    }
    else
    {
        for (VertexNode *vertexNode = _vertices.begin(), *vertexEnd = _vertices.end(); vertexNode != vertexEnd; vertexNode = vertexNode->next())
        {
            if (!vertexNode->data().selected)
                continue;
            
            vertexNode->data().selected = false;
            
            for (SimpleNode<TriangleNode *> 
                 *triangleNode = vertexNode->_triangles.begin(), 
                 *triangleEnd = vertexNode->_triangles.end(); 
                 triangleNode != triangleEnd; 
                 triangleNode = triangleNode->next())
            {
                triangleNode->data()->replaceVertex(vertexNode, _vertices.add(vertexNode->data()));
            }
            
            _vertices.remove(vertexNode);
        }
    }
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::detachSelectedTriangles()
{
    resetTriangleCache();
    
    if (_isUnwrapped)
    {
        for (TexCoordNode *texCoordNode = _texCoords.begin(), *texCoordEnd = _texCoords.end(); texCoordNode != texCoordEnd; texCoordNode = texCoordNode->next())
        {
            TexCoordNode *newTexCoord = NULL;
            
            for (SimpleNode<TriangleNode *> 
                 *triangleNode = texCoordNode->_triangles.begin(), 
                 *triangleEnd = texCoordNode->_triangles.end(); 
                 triangleNode != triangleEnd; 
                 triangleNode = triangleNode->next())
            {
                if (triangleNode->data()->data().selected)
                {
                    if (newTexCoord == NULL)
                        newTexCoord = _texCoords.add(texCoordNode->data());
                    
                    triangleNode->data()->replaceTexCoord(texCoordNode, newTexCoord);
                    texCoordNode->_triangles.remove(triangleNode);
                }
            }
            
            if (!texCoordNode->isUsed())
                _texCoords.remove(texCoordNode);
        }
    }
    else
    {    
        for (VertexNode *vertexNode = _vertices.begin(), *vertexEnd = _vertices.end(); vertexNode != vertexEnd; vertexNode = vertexNode->next())
        {
            VertexNode *newVertex = NULL;
            
            for (SimpleNode<TriangleNode *> 
                 *triangleNode = vertexNode->_triangles.begin(), 
                 *triangleEnd = vertexNode->_triangles.end(); 
                 triangleNode != triangleEnd; 
                 triangleNode = triangleNode->next())
            {
                if (triangleNode->data()->data().selected)
                {
                    if (newVertex == NULL)
                        newVertex = _vertices.add(vertexNode->data());
                        
                    triangleNode->data()->replaceVertex(vertexNode, newVertex);
                    vertexNode->_triangles.remove(triangleNode);
                }
            }
            
            if (!vertexNode->isUsed())
                _vertices.remove(vertexNode);
        }
    }
        
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::splitSelectedTriangles()
{
    resetTriangleCache();
    
    VertexNode *v[9];
    TexCoordNode *t[9];
    
    FPList<TriangleNode, Triangle2> subdivided;
    
    for (VertexEdgeNode *node = _vertexEdges.begin(), *end = _vertexEdges.end(); node != end; node = node->next())
    {
        node->data().half = NULL;
    }
    
    for (TexCoordEdgeNode *node = _texCoordEdges.begin(), *end = _texCoordEdges.end(); node != end; node = node->next())
    {
        node->data().half = NULL;
    }
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        Triangle2 &triQuad = node->data();
        
        if (!triQuad.selected)
        {
            subdivided.add(triQuad);
            continue;
        }
        
        for (uint j = 0; j < triQuad.count(); j++)
        {
            VertexEdge &edge = node->data().vertexEdge(j)->data();
            
            if (edge.half == NULL)
            {
                Vector3D v1 = edge.vertex(0)->data().position;
                Vector3D v2 = edge.vertex(1)->data().position;
                
                Vector3D edgeVertex = (v1 + v2) / 2.0f;
                
                edge.half = _vertices.add(edgeVertex);
            }
            
            v[j] = node->data().vertex(j);
            v[j + triQuad.count()] = edge.half;
        }
        
        for (uint j = 0; j < triQuad.count(); j++)
        {
            TexCoordEdge &edge = node->data().texCoordEdge(j)->data();
            
            if (edge.half == NULL)
            {
                Vector3D t1 = edge.texCoord(0)->data().position;
                Vector3D t2 = edge.texCoord(1)->data().position;
                
                Vector3D edgeTexCoord = (t1 + t2) / 2.0f;
                
                edge.half = _texCoords.add(edgeTexCoord);
            }
            
            t[j] = node->data().texCoord(j);
            t[j + triQuad.count()] = edge.half;
        }
        
        if (triQuad.isQuad())
        {
            /*      
                3----(6)----2
                |     |     |
                |     |     |
               (7)---[8]---(5)
                |     |     |
                |     |     |
                0----(4)----1
    
            */
            
            v[8] = _vertices.add((v[7]->data().position + v[5]->data().position) / 2.0f);
            t[8] = _texCoords.add((t[7]->data().position + t[5]->data().position) / 2.0f);
            
            subdivided.add(Triangle2((VertexNode *[4]) { v[0], v[4], v[8], v[7] }, (TexCoordNode *[4]) { t[0], t[4], t[8], t[7] }, true));
            subdivided.add(Triangle2((VertexNode *[4]) { v[4], v[1], v[5], v[8] }, (TexCoordNode *[4]) { t[4], t[1], t[5], t[8] }, true));
            subdivided.add(Triangle2((VertexNode *[4]) { v[8], v[5], v[2], v[6] }, (TexCoordNode *[4]) { t[8], t[5], t[2], t[6] }, true));
            subdivided.add(Triangle2((VertexNode *[4]) { v[7], v[8], v[6], v[3] }, (TexCoordNode *[4]) { t[7], t[8], t[6], t[3] }, true));
        }
        else
        {
            /*
                   2
                  /\
                 /  \
              *5/____\*4
               /\    /\
              /  \  /  \
             /____\/____\
             0    *3     1
             
            */
            
            subdivided.add(Triangle2((VertexNode *[3]) { v[0], v[3], v[5] }, (TexCoordNode *[3]) { t[0], t[3], t[5] }));
            subdivided.add(Triangle2((VertexNode *[3]) { v[3], v[1], v[4] }, (TexCoordNode *[3]) { t[3], t[1], t[4] }));
            subdivided.add(Triangle2((VertexNode *[3]) { v[5], v[4], v[2] }, (TexCoordNode *[3]) { t[5], t[4], t[2] }));
            subdivided.add(Triangle2((VertexNode *[3]) { v[3], v[4], v[5] }, (TexCoordNode *[3]) { t[3], t[4], t[5] }));
        }
    }
    
    _triangles.moveFrom(subdivided);
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::splitSelectedEdges()
{
    resetTriangleCache();
    
    for (VertexEdgeNode *edgeNode = _vertexEdges.begin(), *end = _vertexEdges.end(); edgeNode != end; edgeNode = edgeNode->next())
    {
        VertexEdge &vertexEdge = edgeNode->data();
        if (!vertexEdge.selected)
            continue;
        
        if (vertexEdge.half == NULL)
        {
            Vector3D v1 = vertexEdge.vertex(0)->data().position;
            Vector3D v2 = vertexEdge.vertex(1)->data().position;
            
            Vector3D edgeVertex = (v1 + v2) / 2.0f;
            
            vertexEdge.half = _vertices.add(edgeVertex);
        }
    }
    
    VertexNode *v[4];
    
    for (VertexEdgeNode *edgeNode = _vertexEdges.begin(), *end = _vertexEdges.end(); edgeNode != end; edgeNode = edgeNode->next())
    {
        VertexEdge &vertexEdge = edgeNode->data();
        if (!vertexEdge.selected)
            continue;
        
        for (uint i = 0; i < 2; i++)
        {
            TriangleNode *triangleNode = vertexEdge.triangle(i);
            if (triangleNode == NULL)
                continue;
            
            Triangle2 &triQuad = triangleNode->data();
            
            VertexEdgeNode *secondEdgeNode = triQuad.findSecondSplitEdgeNode(vertexEdge);
            if (secondEdgeNode == NULL)
                continue;
            
            VertexEdge &secondEdge = secondEdgeNode->data();
            
            if (triQuad.isQuad())
            {
                for (uint k = 0; k < 2; k++)
                {
                    v[0] = secondEdge.half;
                    v[1] = vertexEdge.half;
                    
                    v[2] = vertexEdge.vertex(k);
                    
                    if (v[2]->sharedEdge(secondEdge.vertex(0)))
                        v[3] = secondEdge.vertex(0);
                    else
                        v[3] = secondEdge.vertex(1);
                    
                    if (triQuad.shouldSwapVertices(v[2], v[3]))
                    {
                        swap(v[2], v[3]);
                        swap(v[1], v[0]);
                    }
                    
                    _triangles.add(Triangle2(v, true));
                }                                
            }
            else
            {
                v[0] = secondEdge.half;
                v[1] = vertexEdge.half;
                v[2] = vertexEdge.sharedVertex(secondEdge);
                
                VertexNode *opposite0 = secondEdge.opposite(v[2]);
                VertexNode *opposite1 = vertexEdge.opposite(v[2]);
                
                if (triQuad.shouldSwapVertices(opposite0, opposite1))
                {
                    swap(opposite0, opposite1);
                    swap(v[0], v[1]);
                }
                
                _triangles.add(Triangle2(v, false));
                
                v[2] = opposite1;
                v[3] = opposite0;
                
                swap(v[0], v[2]);
                
                _triangles.add(Triangle2(v, true));                
            }
            
            _triangles.remove(triangleNode);
        }
    }
    
    removeNonUsedVertices();    
    makeTexCoords();
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::splitSelected()
{
    switch (_selectionMode)
    {
        case MeshSelectionModeTriangles:
            splitSelectedTriangles();
            break;
        case MeshSelectionModeEdges:
            splitSelectedEdges();
            break;
        default:
            break;
    }
}

void Mesh2::detachSelected()
{
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
            detachSelectedVertices();
            break;
        case MeshSelectionModeTriangles:
            detachSelectedTriangles();
            break;
        default:
            break;
    }
}

void Mesh2::duplicateSelectedTriangles()
{
    resetTriangleCache();
    resetAlgorithmData();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        Triangle2 &triQuad = node->data();
        
        if (!triQuad.selected)
            continue;
        
        VertexNode *duplicatedVertices[4];
        TexCoordNode *duplicatedTexCoords[4];
        
        for (uint i = 0; i < triQuad.count(); i++)
        {
            VertexNode *originalVertex = triQuad.vertex(i);
            TexCoordNode *originalTexCoord = triQuad.texCoord(i);
            duplicatedVertices[i] = duplicateVertex(originalVertex);
            duplicatedTexCoords[i] = duplicateVertex(originalTexCoord);
        }
        
        node->data().selected = false;
        
        TriangleNode *newTriangle = _triangles.add(Triangle2(duplicatedVertices, duplicatedTexCoords, triQuad.isQuad()));
        newTriangle->data().selected = true;
    }
        
    makeEdges();
    
    setSelectionMode(_selectionMode);    
}

void Mesh2::flipSelectedTriangles()
{
    resetTriangleCache();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        if (node->data().selected)
            node->data().flip();
    }
}

void Mesh2::turnSelectedEdges()
{
    resetTriangleCache();
    
    for (VertexEdgeNode *node = _vertexEdges.begin(), *end = _vertexEdges.end(); node != end; node = node->next())
    {
        if (node->data().selected)
            node->data().turn();
    }
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::flipSelected()
{
    switch (_selectionMode) 
    {
        case MeshSelectionModeTriangles:
            flipSelectedTriangles();
            break;
        case MeshSelectionModeEdges:
            turnSelectedEdges();
            break;
        default:
            break;
    }
}

void Mesh2::flipAllTriangles()
{
    resetTriangleCache();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        node->data().flip();
    }
}

void Mesh2::extrudeSelectedTriangles()
{
    resetTriangleCache();
    resetAlgorithmData();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        Triangle2 &triQuad = node->data();
        
        if (!triQuad.selected)
            continue;
        
        for (uint i = 0; i < triQuad.count(); i++)
        {
            VertexEdge &vertexEdge = node->data().vertexEdge(i)->data();
            
            if (vertexEdge.isNotShared())
            {
                VertexNode *original0 = vertexEdge.vertex(0);
                VertexNode *original1 = vertexEdge.vertex(1);
                
                if (triQuad.shouldSwapVertices(original0, original1))
                    swap(original0, original1);
                
                VertexNode *extruded0 = duplicateVertex(original0);
                VertexNode *extruded1 = duplicateVertex(original1);
                
                addQuad(original0, original1, extruded1, extruded0);
            }
        }
    }
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (node->algorithmData.duplicatePair != NULL)
            node->replaceVertexInSelectedTriangles(node->algorithmData.duplicatePair);
    }
        
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::merge(Mesh2 *mesh)
{
    vector<Vector3D> thisVertices;
    vector<Vector3D> thisTexCoords;
    vector<TriQuad> thisTriangles;
    
    this->toIndexRepresentation(thisVertices, thisTexCoords, thisTriangles);
    
    vector<Vector3D> otherVertices;
    vector<Vector3D> otherTexCoords;
    vector<TriQuad> otherTriangles;
    
    mesh->toIndexRepresentation(otherVertices, otherTexCoords, otherTriangles);
    
    vector<Vector3D> mergedVertices;
    vector<Vector3D> mergedTexCoords;
    vector<TriQuad> mergedTriangles;
    
    for (uint i = 0; i < thisVertices.size(); i++)
        mergedVertices.push_back(thisVertices[i]);
    
    for (uint i = 0; i < otherVertices.size(); i++)
        mergedVertices.push_back(otherVertices[i]);
    
    for (uint i = 0; i < thisTexCoords.size(); i++)
        mergedTexCoords.push_back(thisTexCoords[i]);
    
    for (uint i = 0; i < otherTexCoords.size(); i++)
        mergedTexCoords.push_back(otherTexCoords[i]);
    
    for (uint i = 0; i < thisTriangles.size(); i++)
        mergedTriangles.push_back(thisTriangles[i]);
    
    for (uint i = 0; i < otherTriangles.size(); i++)
    {
        TriQuad triangle = otherTriangles[i];
        for (uint j = 0; j < 4; j++)
        {
            triangle.vertexIndices[j] += thisVertices.size();
            triangle.texCoordIndices[j] += thisTexCoords.size();
        }
        mergedTriangles.push_back(triangle);
    }
    
    this->fromIndexRepresentation(mergedVertices, mergedTexCoords, mergedTriangles);     
}

void Mesh2::computeSoftSelection()
{
    if (!_useSoftSelection)
        return;
    
    Vector3D center;
    Quaternion rotation;
    Vector3D scale;
    
    getSelectionCenterRotationScale(center, rotation, scale);
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (!node->data().selected)
        {
            float sqDistance = center.SqDistance(node->data().position);
            
            node->selectionWeight = 1.0f / expf(sqDistance);
            
            if (node->selectionWeight < 0.1f)
                node->selectionWeight = 0.0f;

            if (node->selectionWeight > 1.0f)
                node->selectionWeight = 1.0f;
        }
        else
        {
            node->selectionWeight = 1.0f;
        }
    }
}
