//
//  Mesh2.cpp
//  OpenGLEditor
//
//  Created by Filip Kunc on 19.06.11.
//  Copyright 2011 Filip Kunc. All rights reserved.
//

#include "Mesh2.h"

Mesh2::Mesh2(float colorComponents[4])
{
    _cachedVertices = NULL;
    _cachedNormals = NULL;
    _cachedColors = NULL;
    
    _selectionMode = MeshSelectionModeVertices;
    
    for (int i = 0; i < 4; i++)
        _colorComponents[i] = colorComponents[i];
}

Mesh2::~Mesh2()
{
    resetCache();
}

void Mesh2::setSelectionMode(MeshSelectionMode value)
{
    _selectionMode = value;
    _cachedVertexSelection.clear();
    _cachedTriangleSelection.clear();
    _cachedEdgeSelection.clear();
    
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
        {
            for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
                _cachedVertexSelection.push_back(node);
        } break;
        case MeshSelectionModeTriangles:
        {
            for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
                node->data.selected = false;                
            
            for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
            {
                _cachedTriangleSelection.push_back(node);
                
                Triangle2 &triangle = node->data;
                if (triangle.selected)
                {
                    for (int i = 0; i < 3; i++)
                        triangle.vertex(i)->data.selected = true;
                }
            }
        } break;
        case MeshSelectionModeEdges:
        {
            for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
                node->data.selected = false;
            
            for (EdgeNode *node = _edges.begin(), *end = _edges.end(); node != end; node = node->next())
            {
                _cachedEdgeSelection.push_back(node);
                
                Edge2 &edge = node->data;
                if (edge.selected)
                {
                    for (int i = 0; i < 2; i++)
                        edge.vertex(i)->data.selected = true;
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
            return _cachedVertexSelection.size();
        case MeshSelectionModeTriangles:
            return _cachedTriangleSelection.size();
        case MeshSelectionModeEdges:
            return _cachedEdgeSelection.size();
        default:
            return 0;
    }
}

bool Mesh2::isSelectedAtIndex(uint index) const
{
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
            return _cachedVertexSelection.at(index)->data.selected;
        case MeshSelectionModeTriangles:
            return _cachedTriangleSelection.at(index)->data.selected;
        case MeshSelectionModeEdges:
            return _cachedEdgeSelection.at(index)->data.selected;
        default:
            return false;
    }
}

void Mesh2::setSelectedAtIndex(bool selected, uint index)
{
    switch (_selectionMode)
    {
        case MeshSelectionModeVertices:
            _cachedVertexSelection.at(index)->data.selected = selected;
            break;
        case MeshSelectionModeTriangles:
        {
            Triangle2 &triangle = _cachedTriangleSelection.at(index)->data;
            triangle.selected = selected;
            for (int i = 0; i < 3; i++)
                triangle.vertex(i)->data.selected = selected;            
        } break;
        case MeshSelectionModeEdges:
        {
            Edge2 &edge = _cachedEdgeSelection.at(index)->data;
            edge.selected = selected;
            for (int i = 0; i < 2; i++)
                edge.vertex(i)->data.selected = selected;
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
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (node->data.selected)
        {
            center += node->data.position;
            selectedCount++;
        }
    }
	if (selectedCount > 0)
		center /= (float)selectedCount;
}

void Mesh2::transformAll(const Matrix4x4 &matrix)
{
    resetCache();
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        Vector3D &v = node->data.position;
        v = matrix.Transform(v);
    }
    
    setSelectionMode(_selectionMode);
}

void Mesh2::transformSelected(const Matrix4x4 &matrix)
{
    resetCache();
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (node->data.selected)
        {
            Vector3D &v = node->data.position;
            v = matrix.Transform(v);
        }
    }
}

void Mesh2::fastMergeSelectedVertices()
{
    Vector3D center = Vector3D();
    
    SimpleList<VertexNode *> selectedNodes;
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (node->data.selected)
        {
            selectedNodes.add(node);
            center += node->data.position;
        }
    }
    
    if (selectedNodes.count() < 2)
        return;
    
    center /= (float)selectedNodes.count();
    
    VertexNode *centerNode = _vertices.add(center);
    
    for (SimpleNode<VertexNode *> *node = selectedNodes.begin(), *end = selectedNodes.end(); node != end; node = node->next())
    {
        node->data->replaceVertex(centerNode);        
    }    
}

void Mesh2::removeDegeneratedTrianglesAndEdges()
{
    removeDegeneratedTriangles();
    removeDegeneratedEdges();    
}

void Mesh2::removeDegeneratedTriangles()
{
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        if (node->data.isDegenerated())
            _triangles.remove(node);
    }
}

void Mesh2::removeDegeneratedEdges()
{
    for (EdgeNode *node = _edges.begin(), *end = _edges.end(); node != end; node = node->next())
    {
        if (node->data.isDegenerated())
            _edges.remove(node);
    }
}

void Mesh2::removeNonUsedVertices()
{
    resetCache();
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (!node->isUsed())
            _vertices.remove(node);
    }
}

void Mesh2::mergeSelectedVertices()
{
    resetCache();
    
    fastMergeSelectedVertices();
    removeDegeneratedTrianglesAndEdges();
    removeNonUsedVertices();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::removeSelectedVertices()
{
    resetCache();
    
    for (VertexNode *node = _vertices.begin(), *end = _vertices.end(); node != end; node = node->next())
    {
        if (node->data.selected)
            _vertices.remove(node);
    }
    
    removeDegeneratedTrianglesAndEdges();
    removeNonUsedVertices();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::removeSelectedTriangles()
{
    resetCache();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        if (node->data.selected)
            _triangles.remove(node);
    }
    
    removeDegeneratedEdges();
    removeNonUsedVertices();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::removeSelectedEdges()
{
    resetCache();
    
    for (EdgeNode *node = _edges.begin(), *end = _edges.end(); node != end; node = node->next())
    {
        if (node->data.selected)
            _edges.remove(node);
    }
    
    removeDegeneratedTrianglesAndEdges();
    removeNonUsedVertices();
    
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

void Mesh2::splitSelectedTriangles()
{
    
}

void Mesh2::splitSelectedEdges()
{
    
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

void Mesh2::flipSelectedTriangles()
{
    resetCache();
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        if (node->data.selected)
            node->data.flip();
    }
}

void Mesh2::turnSelectedEdges()
{
    resetCache();
    
    for (EdgeNode *node = _edges.begin(), *end = _edges.end(); node != end; node = node->next())
    {
        if (node->data.selected)
            node->data.turn();
    }
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}

void Mesh2::flipSelected()
{
    switch (_selectionMode) {
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

void Mesh2::extrudeSelectedTriangles()
{
    resetCache();
    
    vector<ExtrudePair> extrudePairs;
    
    for (TriangleNode *node = _triangles.begin(), *end = _triangles.end(); node != end; node = node->next())
    {
        if (!node->data.selected)
            continue;
        
        for (int i = 0; i < 3; i++)
        {
            Edge2 &edge = node->data.edge(i)->data;
            
            if (edge.isNotShared())
            {
                VertexNode *original0 = edge.vertex(0);
                VertexNode *original1 = edge.vertex(1);
                
                node->data.sortVertices(original0, original1);
                
                VertexNode *extruded0 = findOrCreateVertex(extrudePairs, original0);
                VertexNode *extruded1 = findOrCreateVertex(extrudePairs, original1);
                
                addQuad(original0, original1, extruded1, extruded0);
            }
        }
    }
    
    for (size_t i = 0; i < extrudePairs.size(); i++)
    {
        extrudePairs[i].original->replaceVertexInSelectedTriangles(extrudePairs[i].extruded);
    }
    
    makeEdges();
    
    setSelectionMode(_selectionMode);
}
