/*
Bullet Continuous Collision Detection and Physics Library
Copyright (c) 2003-2006 Erwin Coumans  http://continuousphysics.com/Bullet/

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the use of this software.
Permission is granted to anyone to use this software for any purpose, 
including commercial applications, and to alter it and redistribute it freely, 
subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
*/


#include "btTypedConstraint.h"
#include "BulletDynamics/Dynamics/btRigidBody.h"

static btRigidBody s_fixed(0, 0,0);

#define DEFAULT_DEBUGDRAW_SIZE btScalar(0.3f)

btTypedConstraint::btTypedConstraint(btTypedConstraintType type)
:btTypedObject(type),
m_userConstraintType(-1),
m_userConstraintId(-1),
m_needsFeedback(false),
m_rbA(s_fixed),
m_rbB(s_fixed),
m_appliedImpulse(btScalar(0.)),
m_dbgDrawSize(DEFAULT_DEBUGDRAW_SIZE)
{
	s_fixed.setMassProps(btScalar(0.),btVector3(btScalar(0.),btScalar(0.),btScalar(0.)));
}
btTypedConstraint::btTypedConstraint(btTypedConstraintType type, btRigidBody& rbA)
:btTypedObject(type),
m_userConstraintType(-1),
m_userConstraintId(-1),
m_needsFeedback(false),
m_rbA(rbA),
m_rbB(s_fixed),
m_appliedImpulse(btScalar(0.)),
m_dbgDrawSize(DEFAULT_DEBUGDRAW_SIZE)
{
	s_fixed.setMassProps(btScalar(0.),btVector3(btScalar(0.),btScalar(0.),btScalar(0.)));
}


btTypedConstraint::btTypedConstraint(btTypedConstraintType type, btRigidBody& rbA,btRigidBody& rbB)
:btTypedObject(type),
m_userConstraintType(-1),
m_userConstraintId(-1),
m_needsFeedback(false),
m_rbA(rbA),
m_rbB(rbB),
m_appliedImpulse(btScalar(0.)),
m_dbgDrawSize(DEFAULT_DEBUGDRAW_SIZE)
{
	s_fixed.setMassProps(btScalar(0.),btVector3(btScalar(0.),btScalar(0.),btScalar(0.)));

}




btScalar btTypedConstraint::getMotorFactor(btScalar pos, btScalar lowLim, btScalar uppLim, btScalar vel, btScalar timeFact)
{
	if(lowLim > uppLim)
	{
		return btScalar(1.0f);
	}
	else if(lowLim == uppLim)
	{
		return btScalar(0.0f);
	}
	btScalar lim_fact = btScalar(1.0f);
	btScalar delta_max = vel / timeFact;
	if(delta_max < btScalar(0.0f))
	{
		if((pos >= lowLim) && (pos < (lowLim - delta_max)))
		{
			lim_fact = (lowLim - pos) / delta_max;
		}
		else if(pos  < lowLim)
		{
			lim_fact = btScalar(0.0f);
		}
		else
		{
			lim_fact = btScalar(1.0f);
		}
	}
	else if(delta_max > btScalar(0.0f))
	{
		if((pos <= uppLim) && (pos > (uppLim - delta_max)))
		{
			lim_fact = (uppLim - pos) / delta_max;
		}
		else if(pos  > uppLim)
		{
			lim_fact = btScalar(0.0f);
		}
		else
		{
			lim_fact = btScalar(1.0f);
		}
	}
	else
	{
			lim_fact = btScalar(0.0f);
	}
	return lim_fact;
}

///fills the dataBuffer and returns the struct name (and 0 on failure)
const char*	btTypedConstraint::serialize(void* dataBuffer, btSerializer* serializer) const
{
	btTypedConstraintData* tcd = (btTypedConstraintData*) dataBuffer;

	tcd->m_rbA = (btRigidBodyData*)&m_rbA;
	tcd->m_rbB = (btRigidBodyData*)&m_rbB;

	m_appliedAngularImpulseA.serializeFloat(tcd->m_appliedAngularImpulseA);
	m_appliedAngularImpulseB.serializeFloat(tcd->m_appliedAngularImpulseB);
	m_appliedLinearImpulse.serializeFloat(tcd->m_appliedLinearImpulse);

	tcd->m_objectType = m_objectType;
	tcd->m_needsFeedback = m_needsFeedback;
	tcd->m_userConstraintId =m_userConstraintId;
	tcd->m_userConstraintType =m_userConstraintType;

	tcd->m_appliedImpulse = float(m_appliedImpulse);
	tcd->m_dbgDrawSize = float(m_dbgDrawSize );

	tcd->m_disableCollisionsBetweenLinkedBodies = false;

	int i;
	for (i=0;i<m_rbA.getNumConstraintRefs();i++)
		if (m_rbA.getConstraintRef(i) == this)
			tcd->m_disableCollisionsBetweenLinkedBodies = true;
	for (i=0;i<m_rbB.getNumConstraintRefs();i++)
		if (m_rbB.getConstraintRef(i) == this)
			tcd->m_disableCollisionsBetweenLinkedBodies = true;

	return "btTypedConstraintData";
}

