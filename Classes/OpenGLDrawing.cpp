/*
 *  OpenGLDrawing.mm
 *  OpenGLEditor
 *
 *  Created by Filip Kunc on 6/22/09.
 *  For license see LICENSE.TXT
 *
 */

#include "OpenGLDrawing.h"

void DrawCube(float size)
{
	static uint indices[36] =
	{
		0, 1, 2,
		3, 2, 1,
		4, 0, 6,
		6, 0, 2,
		5, 1, 4,
		4, 1, 0,
		7, 3, 1,
		7, 1, 5,
		5, 4, 7,
		7, 4, 6,
		7, 2, 3,
		7, 6, 2
	};	
	
	static float vertices[8 * 3] =
	{	
		 1,  1,  1,
		-1,  1,  1,
		 1, -1,  1,
		-1, -1,  1,
		 1,  1, -1,
		-1,  1, -1,
		 1, -1, -1,
		-1, -1, -1
	};
	
	size *= 0.5f;
	
	glPushMatrix();
	glScalef(size, size, size);

	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, 0, vertices);
	glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, indices);
	glDisableClientState(GL_VERTEX_ARRAY);
	
	glPopMatrix();
}

void DrawSphere(float radius, int lats, int longs) 
{
	for (int i = 1; i <= lats; i++) 
	{
		float lat0 = FLOAT_PI * (-0.5f + (float)(i - 1) / (float)lats);
		float z0  = radius * sinf(lat0);
		float zr0 =  radius * cosf(lat0);
		
		float lat1 = FLOAT_PI * (-0.5f + (float)i / (float)lats);
		float z1 = radius * sinf(lat1);
		float zr1 = radius * cosf(lat1);
		
		glBegin(GL_QUAD_STRIP);
		for (int j = 0; j <= longs; j++) 
		{
			float lng = 2 * FLOAT_PI * (float)(j - 1) / (float)longs;
			float x = cosf(lng);
			float y = sinf(lng);
			glNormal3f(x * zr1, y * zr1, z1);
			glVertex3f(x * zr1, y * zr1, z1);
			glNormal3f(x * zr0, y * zr0, z0);
			glVertex3f(x * zr0, y * zr0, z0);
		}
		glEnd();
	}
}

void DrawCone(float width, float height, float offset)
{
	glBegin(GL_TRIANGLE_FAN);
    glVertex3f(0, offset + height, 0);
    float x, z;
    for (float rads = 0.0f; rads < FLOAT_PI * 2.0f; rads += 0.1f)
    {
        x = cosf(rads) * width;
        z = sinf(rads) * width;
        glVertex3f(x, offset, z);
    }
    x = cosf(0.0f) * width;
    z = sinf(0.0f) * width;
    glVertex3f(x, offset, z);
    glEnd();
}

void DrawLine(float size)
{
	glLineWidth(1.5f);
	glBegin(GL_LINES);
	glVertex3f(0, 0, 0);
	glVertex3f(0, size, 0);
	glEnd();
	glLineWidth(1.0f);
}

void DrawArrow(float size)
{
    DrawCone(size * 0.05f, size * 0.15f, size);
    //glEnable(GL_BLEND);
    //glEnable(GL_LINE_SMOOTH);
    glLineWidth(1.5f);
    glBegin(GL_LINES);
    glVertex3f(0, 0, 0);
    glVertex3f(0, size, 0);
    glEnd();
    glLineWidth(1.0f);
    //glDisable(GL_LINE_SMOOTH);
    //glDisable(GL_BLEND);
}

void DrawCubeArrow(float size)
{
	glPushMatrix();
	glTranslatef(0, size, 0);
	DrawCube(size * 0.08f);
	glPopMatrix();
	
	glLineWidth(1.5f);
    glBegin(GL_LINES);
    glVertex3f(0, 0, 0);
    glVertex3f(0, size, 0);
    glEnd();
    glLineWidth(1.0f);
}

void DrawCenterCube(float size)
{
	DrawCube(size * 0.2f);
}

void DrawPlane(float size, float sizeOffset)
{
    size += sizeOffset;
    
    glBegin(GL_QUADS);
    glVertex3f(sizeOffset, 0, sizeOffset);
    glVertex3f(size, 0, sizeOffset);
    glVertex3f(size, 0, size);
    glVertex3f(sizeOffset, 0, size);
    glEnd();
}

void DrawPlane(Vector3D a, Vector3D b, float size)
{
	Vector3D vertices[] = 
	{
		-a - b,
		a - b,
		a + b,
		-a + b
	};
	
	glBegin(GL_QUADS);
		
	for (int i = 0; i < 4; i++)
	{
		Vector3D v = vertices[i];
		v *= size;
		glVertex3f(v.x, v.y, v.z);
	}
	
	glEnd();
}

void DrawSelectionPlane(PlaneAxis plane)
{
	const float size = 4000.0f;
	
	switch (plane)
	{
		case PlaneAxis::X:
			glBegin(GL_QUADS);
			glVertex3f(0, -size, -size);
			glVertex3f(0, -size,  size);
			glVertex3f(0,  size,  size);
			glVertex3d(0,  size, -size);
			glEnd();
			break;
		case PlaneAxis::Y:
			glBegin(GL_QUADS);
			glVertex3f(-size, 0, -size);
			glVertex3f(-size, 0,  size);
			glVertex3f( size, 0,  size);
			glVertex3d( size, 0, -size);
			glEnd();
			break;
		case PlaneAxis::Z:
			glBegin(GL_QUADS);
			glVertex3f(-size, -size, 0);
			glVertex3f(-size,  size, 0);
			glVertex3f( size,  size, 0);
			glVertex3d( size, -size, 0);
			glEnd();
			break;
		default:
			break;
	}
}

void DrawCircle(float size)
{
	//glEnable(GL_BLEND);
	//glEnable(GL_LINE_SMOOTH);
    glLineWidth(2.0f);
    glBegin(GL_LINE_LOOP);
    float rads_step = FLOAT_PI * 0.01f;
    for (float rads = 0.0f; rads < FLOAT_PI * 2.0f; rads += rads_step)
        glVertex3f(sinf(rads) * size, 0.0f, cosf(rads) * size);
    glEnd();
    glLineWidth(1.0f);
    //glDisable(GL_LINE_SMOOTH);
    //glDisable(GL_BLEND);
}

#if defined(__APPLE__)
#define RGBA_SELECTION
#elif defined(WIN32) || defined(__linux__)
#define RGB_SELECTION
#endif

#if defined(RGB_SELECTION)

union RgbColor
{
    GLuint colorIndex : 24;
    GLubyte components[3];
    struct
    {
        GLubyte r;
        GLubyte g;
        GLubyte b;
    };
};

#endif

void ColorIndex(uint colorIndex)
{
#if defined(RGB_SELECTION)
    RgbColor color;
    color.colorIndex = colorIndex;
    glColor3ubv(color.components);
#elif defined(RGBA_SELECTION)
    glColor4ubv((GLubyte *)&colorIndex);
#endif
}

void ColorIndices(vector<uint> &colorIndices)
{
#if defined(RGB_SELECTION)
    vector<GLubyte> colorComponents;
    
    for (uint i = 0; i < colorIndices.size(); i++)
    {
        RgbColor color;
        color.colorIndex = colorIndices[i];

        colorComponents.push_back(color.components[0]);
        colorComponents.push_back(color.components[1]);
        colorComponents.push_back(color.components[2]);
    }
    
    GLubyte *colorPtr = (GLubyte *)&colorComponents[0];
    glColorPointer(3, GL_UNSIGNED_BYTE, 0, colorPtr);
#elif defined(RGBA_SELECTION)
    GLubyte *colorPtr = (GLubyte *)&colorIndices[0];
    glColorPointer(4, GL_UNSIGNED_BYTE, 0, colorPtr);
#endif
}

#if defined(RGB_SELECTION)
const uint kMaxSelectedIndicesCount = 2000 * 2000;  // max width * max height resolution

GLubyte colorBuffer[kMaxSelectedIndicesCount * 3];
#endif

void ReadSelectedIndices(int x, int y, int width, int height, uint *selectedIndices)
{
#if defined(RGB_SELECTION)
    uint count = (uint)width * (uint)height;
    
    memset(colorBuffer, 0, count * 3);
        
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glReadPixels(x, y, width, height, GL_RGB, GL_UNSIGNED_BYTE, colorBuffer);
    GetGLError();

    for (uint i = 0; i < count; i++)
    {
        RgbColor color;
        color.components[0] = colorBuffer[i * 3 + 0];
        color.components[1] = colorBuffer[i * 3 + 1];
        color.components[2] = colorBuffer[i * 3 + 2];
        
        selectedIndices[i] = color.colorIndex;
    }
#elif defined(RGBA_SELECTION)
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glReadPixels(x, y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, selectedIndices);
#endif
}
