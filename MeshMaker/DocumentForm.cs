﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using MeshMakerCppCLI;
using System.Diagnostics;
using Chocolate;

namespace MeshMaker
{
    public partial class DocumentForm : Form, IDocumentDelegate
    {
        MyDocument document;
        ToolStripButton[] manipulatorButtons;

        public DocumentForm()
        {
            InitializeComponent();
            perspectiveView.SharedContextView = leftView;
            topView.SharedContextView = leftView;
            frontView.SharedContextView = leftView;
            this.Load += new EventHandler(DocumentForm_Load);
            this.FormClosing += new FormClosingEventHandler(DocumentForm_FormClosing);
        }

        void DocumentForm_FormClosing(object sender, FormClosingEventArgs e)
        {
            Process.GetCurrentProcess().Kill();
        }

        void DocumentForm_Load(object sender, EventArgs e)
        {
            if (Tools.SafeDesignMode)
                return;

            toolStripButtonAddCube.Tag = MeshType.Cube;
            toolStripButtonAddCylinder.Tag = MeshType.Cylinder;
            toolStripButtonAddIcosahedron.Tag = MeshType.Icosahedron;
            toolStripButtonAddPlane.Tag = MeshType.Plane;
            toolStripButtonAddSphere.Tag = MeshType.Sphere;

            cubeToolStripMenuItem.Tag = MeshType.Cube;
            cylinderToolStripMenuItem.Tag = MeshType.Cylinder;
            icosahedronToolStripMenuItem.Tag = MeshType.Icosahedron;
            planeToolStripMenuItem.Tag = MeshType.Plane;
            sphereToolStripMenuItem.Tag = MeshType.Sphere;

            toolStripButtonSelect.Tag = ManipulatorType.Default;
            toolStripButtonTranslate.Tag = ManipulatorType.Translation;
            toolStripButtonRotate.Tag = ManipulatorType.Rotation;
            toolStripButtonScale.Tag = ManipulatorType.Scale;

            manipulatorButtons = new ToolStripButton[] { toolStripButtonSelect, 
                toolStripButtonTranslate, toolStripButtonRotate, toolStripButtonScale };

            toolStripComboBoxEditMode.Items.Add(EditMode.Items);
            toolStripComboBoxEditMode.Items.Add(EditMode.Vertices);
            toolStripComboBoxEditMode.Items.Add(EditMode.Triangles);
            toolStripComboBoxEditMode.Items.Add(EditMode.Edges);

            toolStripComboBoxEditMode.SelectedItem = EditMode.Items;
            toolStripComboBoxEditMode.SelectedIndexChanged += new EventHandler(toolStripComboBoxEditMode_SelectedIndexChanged);

            document = new MyDocument(this);
            document.setViews(leftView, topView, frontView, perspectiveView);

            toolStripComboBoxViewMode.Items.Add(ViewMode.SolidFlat);
            toolStripComboBoxViewMode.Items.Add(ViewMode.SolidSmooth);
            toolStripComboBoxViewMode.Items.Add(ViewMode.MixedWireSolid);
            toolStripComboBoxViewMode.Items.Add(ViewMode.Wireframe);
            toolStripComboBoxViewMode.Items.Add(ViewMode.Unwrap);

            toolStripComboBoxViewMode.SelectedItem = document.viewMode;
            toolStripComboBoxViewMode.SelectedIndexChanged += new EventHandler(toolStripComboBoxViewMode_SelectedIndexChanged);            
        }

        void toolStripComboBoxViewMode_SelectedIndexChanged(object sender, EventArgs e)
        {
            document.viewMode = (ViewMode)toolStripComboBoxViewMode.SelectedItem;
        }

        void toolStripComboBoxEditMode_SelectedIndexChanged(object sender, EventArgs e)
        {
            document.changeEditMode();
        }

        private void addItem(object sender, EventArgs e)
        {
            var button = (ToolStripItem)sender;
            document.addItem((MeshType)button.Tag, 20);
        }

        private void currentManipulatorClicked(object sender, EventArgs e)
        {
            foreach (var button in manipulatorButtons)
            {
                if (button == sender)
                {
                    button.Checked = true;
                    document.CurrentManipulator = (ManipulatorType)button.Tag;
                }
                else
                {
                    button.Checked = false;
                }
            }
        }

        private void selectionLeave(object sender, EventArgs e)
        {
            parseSelectionValue(sender);
        }

        private void selectionKeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode != Keys.Enter)
                return;

            parseSelectionValue(sender);
        }

        void parseSelectionValue(object sender)
        {
            float selectionValue;

            if (sender == toolStripTextBoxSelectionX)
            {
                if (float.TryParse(toolStripTextBoxSelectionX.Text, out selectionValue))
                    document.selectionX = selectionValue;
            }
            else if (sender == toolStripTextBoxSelectionY)
            {
                if (float.TryParse(toolStripTextBoxSelectionY.Text, out selectionValue))
                    document.selectionY = selectionValue;
            }
            else if (sender == toolStripTextBoxSelectionZ)
            {
                if (float.TryParse(toolStripTextBoxSelectionZ.Text, out selectionValue))
                    document.selectionZ = selectionValue;
            }
        }

        #region Splitter sync

        bool ignoreSplitterMoved = true;

        private void topSplit_SplitterMoved(object sender, SplitterEventArgs e)
        {
            if (ignoreSplitterMoved)
                return;

            bottomSplit.SplitterDistance = e.SplitX;
            ignoreSplitterMoved = true;
        }

        private void bottomSplit_SplitterMoved(object sender, SplitterEventArgs e)
        {
            if (ignoreSplitterMoved)
                return;

            topSplit.SplitterDistance = e.SplitX;
            ignoreSplitterMoved = true;
        }

        private void topSplit_SplitterMoving(object sender, SplitterCancelEventArgs e)
        {
            ignoreSplitterMoved = false;
        }

        private void bottomSplit_SplitterMoving(object sender, SplitterCancelEventArgs e)
        {
            ignoreSplitterMoved = false;
        }

        private void toggleOneViewFourViewMenuItem_Click(object sender, EventArgs e)
        {
            //// one view -> four views
            if (mainSplit.Panel1Collapsed)
            {
                mainSplit.Panel1Collapsed = false;
                bottomSplit.Panel1Collapsed = false;
                perspectiveView.CurrentCameraMode = CameraMode.Perspective;
            }
            else // four views -> one view
            {
                Point screenPoint = Control.MousePosition;
                foreach (OpenGLSceneView view in document.Views)
                {
                    Point clientPoint = view.PointToClient(screenPoint);
                    if (view.ClientRectangle.Contains(clientPoint))
                    {
                        perspectiveView.CurrentCameraMode = view.CurrentCameraMode;
                        mainSplit.Panel1Collapsed = true;
                        bottomSplit.Panel1Collapsed = true;
                        return;
                    }
                }

                Trace.WriteLine("No view is under mouse");
            }
        }

        #endregion
        
        #region Keyboard

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            // this allows to process keys in DocumentForm_KeyDown
            foreach (var view in document.Views)
            {
                if (view.Focused)
                    base.ProcessKeyMessage(ref msg);
            }

            // but we also allow standard processing
            return base.ProcessCmdKey(ref msg, keyData);
        }

        void DocumentForm_KeyDown(object sender, KeyEventArgs e)
        {
            switch (e.KeyCode)
            {
                case Keys.Space:
                    toggleOneViewFourViewMenuItem_Click(this, EventArgs.Empty);
                    break;                
            }
        }

        #endregion              
    
        #region IDocumentDelegate Members

        public ToolStripComboBox editModePopup
        {
            get { return toolStripComboBoxEditMode; }
        }

        public void updateSelectionValues()
        {
            toolStripTextBoxSelectionX.Text = document.selectionX.ToString("f2");
            toolStripTextBoxSelectionY.Text = document.selectionY.ToString("f2");
            toolStripTextBoxSelectionZ.Text = document.selectionZ.ToString("f2");
            toolStripButtonColor.BackColor = document.color;
            toolStripButtonColor.Invalidate();
        }

        #endregion        

        private void undoToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.undo();
        }

        private void redoToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.redo();
        }

        private void cutToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.cut();
        }

        private void copyToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.copy();
        }

        private void pasteToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.paste();
        }

        private void duplicateToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.duplicateSelected();
        }

        private void deleteToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.deleteSelected();
        }

        private void selectAllToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.selectAll();
        }

        private void invertSelectionToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.invertSelection();
        }

        private void hideSelectedToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.hideSelected();
        }

        private void unhideAllToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.unhideAll();
        }

        private void mergeToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.mergeSelected();
        }

        private void splitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.splitSelected();
        }

        private void flipToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.flipSelected();
        }

        private void subdivisionToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.subdivision();
        }

        private void detachToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.detachSelected();
        }

        private void extrudeToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.extrudeSelected();
        }

        private void triangulateToolStripMenuItem_Click(object sender, EventArgs e)
        {
            document.triangulateSelected();
        }

        private void newToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }

        private void openToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }

        private void saveToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }

        private void saveAsToolStripMenuItem_Click(object sender, EventArgs e)
        {

        }

        private void exitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Process.GetCurrentProcess().Kill();
        }

        private void toolStripButtonColor_Click(object sender, EventArgs e)
        {
            using (ColorDialog dlg = new ColorDialog())
            {
                dlg.Color = document.color;
                if (dlg.ShowDialog() == DialogResult.OK)
                {
                    document.color = dlg.Color;
                    toolStripButtonColor.BackColor = document.color;
                }
            }
        }
    }
}
