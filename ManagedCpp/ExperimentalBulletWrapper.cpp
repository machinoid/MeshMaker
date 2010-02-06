/*
 *  ExperimentalBulletWrapper.cpp
 *  OpenGLEditor
 *
 *  Created by Filip Kunc on 04/02/10.
 *  For license see LICENSE.TXT
 *
 */

#include "ExperimentalBulletWrapper.h"
#include "MarshalHelpers.h"
using namespace std;

namespace ManagedCpp
{
	ExperimentalBulletWrapper::ExperimentalBulletWrapper(String ^fileName)
	{
		string nativeFileName = NativeString(fileName);
		wrapper = new BulletWrapperHelper(nativeFileName.c_str());
	}

	void ExperimentalBulletWrapper::DebugDraw()
	{
		wrapper->dynamicsWorld->debugDrawWorld();
	}

	//#pragma mark OpenGLManipulatingModel implementation

	void ExperimentalBulletWrapper::Draw(uint index, CocoaBool forSelection, ViewMode mode)
	{
		if (!forSelection)
		{
			this->DebugDraw();
		}
	}

	uint ExperimentalBulletWrapper::Count::get()
	{
		return 1U;
	}

	CocoaBool ExperimentalBulletWrapper::IsSelected(uint index)
	{
		return NO;
	}

	void ExperimentalBulletWrapper::SetSelected(CocoaBool selected, uint index)
	{

	}

	void ExperimentalBulletWrapper::CloneSelected() { }
	void ExperimentalBulletWrapper::RemoveSelected() { }	
	void ExperimentalBulletWrapper::WillSelect() { }
	void ExperimentalBulletWrapper::DidSelect() { }
}