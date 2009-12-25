﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using ManagedCpp;
using HotChocolate;
using HotChocolate.Bindings;
using System.Diagnostics;
using System.IO;

namespace OpenGLEditorWindows
{
    public partial class Form1 : Form, OpenGLSceneViewDelegate
    {
        ItemCollection items;
        OpenGLManipulatingController itemsController;
        OpenGLManipulatingController meshController;
        UndoManager undo;

        PropertyObserver<float> observerSelectionX;
        PropertyObserver<float> observerSelectionY;
        PropertyObserver<float> observerSelectionZ;

        bool manipulationFinished;
        List<ItemManipulationState> oldManipulations;
        MeshManipulationState oldMeshManipulation;

        string lastFileName = null;
        string fileDialogFilter = "Native format (*.model3D)|*.model3D";

        public Form1()
        {
            InitializeComponent();

            if (this.DesignMode)
                return;

            items = new ItemCollection();
            itemsController = new OpenGLManipulatingController();
            meshController = new OpenGLManipulatingController();
            undo = new UndoManager();

            openGLSceneViewLeft.CurrentCameraMode = CameraMode.CameraModeLeft;
            openGLSceneViewTop.CurrentCameraMode = CameraMode.CameraModeTop;
            openGLSceneViewFront.CurrentCameraMode = CameraMode.CameraModeFront;
            openGLSceneViewPerspective.CurrentCameraMode = CameraMode.CameraModePerspective;

            itemsController.Model = items;

            OnEachViewDo(view => view.CurrentManipulator = ManipulatorType.ManipulatorTypeDefault);

            itemsController.CurrentManipulator = openGLSceneViewLeft.CurrentManipulator;

            OnEachViewDo(view =>
                {
                    view.Displayed = view.Manipulated = itemsController;
                    view.TheDelegate = this;
                });

            textBoxX.TextBox.BindString<float>("Text", this, "SelectionX");
            textBoxY.TextBox.BindString<float>("Text", this, "SelectionY");
            textBoxZ.TextBox.BindString<float>("Text", this, "SelectionZ");

            BindSelectionXYZ(itemsController);
            BindSelectionXYZ(meshController);

            observerSelectionX = this.ObserveProperty<float>("SelectionX");
            observerSelectionY = this.ObserveProperty<float>("SelectionY");
            observerSelectionZ = this.ObserveProperty<float>("SelectionZ");

            manipulationFinished = true;
            oldManipulations = null;
            oldMeshManipulation = null;

            undo.NeedsSaveChanged += new EventHandler(undo_NeedsSaveChanged);
            this.FormClosing += new FormClosingEventHandler(Form1_FormClosing);
        }

        void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (undo.NeedsSave)
            {
                DialogResult result = MessageBox.Show(
                    "Do you want to save this document?", 
                    "Question", 
                    MessageBoxButtons.YesNoCancel);

                switch (result)
                {
                    case DialogResult.Cancel:
                        e.Cancel = true;
                        return;
                    case DialogResult.Yes:
                        saveToolStripMenuItem_Click(this, EventArgs.Empty);
                        return;
                    case DialogResult.No:
                    default:
                        return;
                }
            }
        }

        void undo_NeedsSaveChanged(object sender, EventArgs e)
        {
            StringBuilder formTitle = new StringBuilder();
            formTitle.Append("OpenGL Editor - ");
            if (string.IsNullOrEmpty(lastFileName))
                formTitle.Append("Untitled");
            else
                formTitle.Append(Path.GetFileNameWithoutExtension(lastFileName));
            if (undo.NeedsSave)
                formTitle.Append(" *");
            this.Text = formTitle.ToString();
        }

        #region Bindings magic

        void BindSelectionXYZ(OpenGLManipulatingController controller)
        {
            controller.ObserverSelectionX.WillChange += new EventHandler(ObserverSelectionX_WillChange);
            controller.ObserverSelectionY.WillChange += new EventHandler(ObserverSelectionY_WillChange);
            controller.ObserverSelectionZ.WillChange += new EventHandler(ObserverSelectionZ_WillChange);
            controller.ObserverSelectionX.DidChange += new EventHandler(ObserverSelectionX_DidChange);
            controller.ObserverSelectionY.DidChange += new EventHandler(ObserverSelectionY_DidChange);
            controller.ObserverSelectionZ.DidChange += new EventHandler(ObserverSelectionZ_DidChange);
        }

        void ObserverSelectionX_WillChange(object sender, EventArgs e)
        {
            observerSelectionX.RaiseWillChange();
        }

        void ObserverSelectionY_WillChange(object sender, EventArgs e)
        {
            observerSelectionY.RaiseWillChange();
        }

        void ObserverSelectionZ_WillChange(object sender, EventArgs e)
        {
            observerSelectionZ.RaiseWillChange();
        }

        void ObserverSelectionX_DidChange(object sender, EventArgs e)
        {
            observerSelectionX.RaiseDidChange();
        }

        void ObserverSelectionY_DidChange(object sender, EventArgs e)
        {
            observerSelectionY.RaiseDidChange();
        }

        void ObserverSelectionZ_DidChange(object sender, EventArgs e)
        {
            observerSelectionZ.RaiseDidChange();
        }

        [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public float SelectionX
        {
            get { return Manipulated.SelectionX; }
            set
            {
                ManipulationStarted();
                Manipulated.SelectionX = value;
                ManipulationEnded();
            }
        }

        [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public float SelectionY
        {
            get { return Manipulated.SelectionY; }
            set
            {
                ManipulationStarted();
                Manipulated.SelectionY = value;
                ManipulationEnded();
            }
        }

        [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public float SelectionZ
        {
            get { return Manipulated.SelectionZ; }
            set
            {
                ManipulationStarted();
                Manipulated.SelectionZ = value;
                ManipulationEnded();
            }
        }

        #endregion

        private void OnEachViewDo(Action<OpenGLSceneView> actionOnView)
        {
            actionOnView(openGLSceneViewLeft);
            actionOnView(openGLSceneViewTop);
            actionOnView(openGLSceneViewFront);
            actionOnView(openGLSceneViewPerspective);
        }

        private void SetManipulator(ManipulatorType manipulator)
        {
            OnEachViewDo(view => view.CurrentManipulator = manipulator);
            Manipulated.CurrentManipulator = manipulator;
            OnEachViewDo(view => view.Invalidate());

            btnSelect.Checked = btnTranslate.Checked = btnRotate.Checked = btnScale.Checked = false;
            switch (manipulator)
            {
                case ManipulatorType.ManipulatorTypeDefault:
                    btnSelect.Checked = true;
                    break;
                case ManipulatorType.ManipulatorTypeRotation:
                    btnRotate.Checked = true;
                    break;
                case ManipulatorType.ManipulatorTypeScale:
                    btnScale.Checked = true;
                    break;
                case ManipulatorType.ManipulatorTypeTranslation:
                    btnTranslate.Checked = true;
                    break;
                default:
                    break;
            }
        }

        OpenGLManipulatingController Manipulated
        {
            get { return openGLSceneViewLeft.Manipulated as OpenGLManipulatingController; }
            set
            {
                value.CurrentManipulator = openGLSceneViewLeft.CurrentManipulator;

                OnEachViewDo(view => view.Manipulated = value);
                OnEachViewDo(view => view.Invalidate());
            }
        }

        Mesh CurrentMesh
        {
            get { return meshController.Model as Mesh; }
        }

        private void EditMesh(MeshSelectionMode mode)
        {
            int index = itemsController.LastSelectedIndex;
            if (index > -1)
            {
                Item item = items.GetItem((uint)index);
                item.GetMesh().SelectionMode = mode;
                meshController.Model = item.GetMesh();
                meshController.SetTransform(item);
                Manipulated = meshController;
            }
        }

        private void EditItems()
        {
            Mesh mesh = CurrentMesh;
            if (mesh != null)
                mesh.SelectionMode = MeshSelectionMode.MeshSelectionModeVertices;

            itemsController.Model = items;
            itemsController.SetTransform(null);
            Manipulated = itemsController;
        }

        private void ChangeEditMode(EditMode editMode)
        {
            switch (editMode)
            {
                case EditMode.EditModeItems:
                    EditItems();
                    break;
                case EditMode.EditModeTriangles:
                    EditMesh(MeshSelectionMode.MeshSelectionModeTriangles);
                    break;
                case EditMode.EditModeVertices:
                    EditMesh(MeshSelectionMode.MeshSelectionModeVertices);
                    break;
                case EditMode.EditModeEdges:
                    EditMesh(MeshSelectionMode.MeshSelectionModeEdges);
                    break;
                default:
                    break;
            }
        }

        private void AddItem(MeshType type, uint steps)
        {
            Item item = new Item();
            item.GetMesh().MakeMesh(type, steps);

            itemsController.ChangeSelection(0);
            item.Selected = 1;
            items.AddItem(item);
            itemsController.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());

            undo.PrepareUndo(string.Format("Add {0}", type.ToDisplayString()),
                Invocation.Create(type, steps, RemoveItem));
        }

        private void RemoveItem(MeshType type, uint steps)
        {
            itemsController.ChangeSelection(0);
            items.RemoveAt((int)items.Count - 1);
            OnEachViewDo(view => view.Invalidate());

            // simple test for undo/redo
            undo.PrepareUndo(string.Format("Add {0}", type.ToDisplayString()),
                Invocation.Create(type, steps, AddItem));
        }

        private void btnSelect_Click(object sender, EventArgs e)
        {
            SetManipulator(ManipulatorType.ManipulatorTypeDefault);
        }

        private void btnTranslate_Click(object sender, EventArgs e)
        {
            SetManipulator(ManipulatorType.ManipulatorTypeTranslation);
        }

        private void btnRotate_Click(object sender, EventArgs e)
        {
            SetManipulator(ManipulatorType.ManipulatorTypeRotation);
        }

        private void btnScale_Click(object sender, EventArgs e)
        {
            SetManipulator(ManipulatorType.ManipulatorTypeScale);
        }

        private void btnAddCube_Click(object sender, EventArgs e)
        {
            AddItem(MeshType.MeshTypeCube, 1);
        }

        private void AddItemDialog(MeshType type)
        {
            using (AddItemWithStepsDialog dlg = new AddItemWithStepsDialog())
            {
                if (dlg.ShowDialog() == DialogResult.OK)
                {
                    AddItem(type, dlg.Steps);
                }
            }
        }

        private void btnAddCylinder_Click(object sender, EventArgs e)
        {
            AddItemDialog(MeshType.MeshTypeCylinder);
        }

        private void btnAddSphere_Click(object sender, EventArgs e)
        {
            AddItemDialog(MeshType.MeshTypeSphere);
        }

        private void undoToolStripMenuItem_Click(object sender, EventArgs e)
        {
            undo.Undo();
        }

        private void redoToolStripMenuItem_Click(object sender, EventArgs e)
        {
            undo.Redo();
        }

        void SwapManipulations(List<ItemManipulationState> old,
            List<ItemManipulationState> current)
        {
            Trace.WriteLine("swapManipulationsWithOld:current:");
            Trace.Assert(old.Count == current.Count, "old.Count == current.Count");
            items.CurrentManipulations = old;

            undo.PrepareUndo("Manipulations",
                Invocation.Create(current, old, SwapManipulations));

            itemsController.UpdateSelection();
            Manipulated = itemsController;
        }

        void SwapMeshManipulation(MeshManipulationState old,
            MeshManipulationState current)
        {
            Trace.WriteLine("swapMeshManipulationWithOld:current:");

            items.CurrentMeshManipulation = old;

            undo.PrepareUndo("Mesh Manipulation",
                Invocation.Create(current, old, SwapMeshManipulation));

            itemsController.UpdateSelection();
            meshController.UpdateSelection();
            Manipulated = meshController;
        }

        void SwapAllItems(List<Item> old, List<Item> current, string actionName)
        {
            Trace.WriteLine("swapAllItemsWithOld:current:actionName:");

            Trace.WriteLine(string.Format("items count before set = {0}", items.Count));
            items.AllItems = old;
            Trace.WriteLine(string.Format("items count after set = {0}", items.Count));

            undo.PrepareUndo(actionName,
                Invocation.Create(current, old, actionName, SwapAllItems));

            itemsController.UpdateSelection();
            Manipulated = itemsController;
        }

        void SwapMeshFullState(MeshFullState old, MeshFullState current, string actionName)
        {
            Trace.WriteLine("swapMeshFullStateWithOld:current:actionName:");

            items.CurrentMeshFull = old;

            undo.PrepareUndo(actionName,
                Invocation.Create(current, old, actionName, SwapMeshFullState));

            itemsController.UpdateSelection();
            meshController.UpdateSelection();
            Manipulated = meshController;
        }

        void AllItemsAction(string actionName, Action action)
        {
            var oldItems = items.AllItems;
            Trace.WriteLine(string.Format("oldItems count = {0}", oldItems.Count));

            action();

            var currentItems = items.AllItems;
            Trace.WriteLine(string.Format("currentItems count = {0}", currentItems.Count));

            undo.PrepareUndo(actionName,
                Invocation.Create(oldItems, currentItems, actionName, SwapAllItems));
        }

        void FullMeshAction(string actionName, Action action)
        {
            MeshFullState oldState = items.CurrentMeshFull;

            action();

            MeshFullState currentState = items.CurrentMeshFull;
            undo.PrepareUndo(actionName,
                Invocation.Create(oldState, currentState, actionName, SwapMeshFullState));
        }

        public void ManipulationStarted()
        {
            Trace.WriteLine("manipulationStarted");
            manipulationFinished = false;

            if (Manipulated == itemsController)
            {
                oldManipulations = items.CurrentManipulations;
            }
            else if (Manipulated == meshController)
            {
                oldMeshManipulation = items.CurrentMeshManipulation;
            }
        }

        public void ManipulationEnded()
        {
            Trace.WriteLine("manipulationEnded");
            manipulationFinished = true;

            if (Manipulated == itemsController)
            {
                undo.PrepareUndo("Manipulations",
                    Invocation.Create(oldManipulations,
                        items.CurrentManipulations, SwapManipulations));

                oldManipulations = null;
            }
            else if (Manipulated == meshController)
            {
                undo.PrepareUndo("Mesh Manipulation",
                    Invocation.Create(oldMeshManipulation,
                        items.CurrentMeshManipulation, SwapMeshManipulation));

                oldMeshManipulation = null;
            }
        }

        private void cloneToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Trace.WriteLine("cloneSelected:");
            if (Manipulated.SelectedCount <= 0)
                return;

            bool startManipulation = false;
            if (!manipulationFinished)
            {
                startManipulation = true;
                ManipulationEnded();
            }

            if (Manipulated == itemsController)
            {
                var selection = items.CurrentSelection;
                undo.PrepareUndo("Clone",
                    Invocation.Create(selection, UndoCloneSelected));

                Manipulated.CloneSelected();
            }
            else
            {
                FullMeshAction("Clone", () => Manipulated.CloneSelected());
            }

            OnEachViewDo(view => view.Invalidate());

            if (startManipulation)
            {
                ManipulationStarted();
            }
        }

        void RedoCloneSelected(List<uint> selection)
        {
            Trace.WriteLine("redoCloneSelected:");

            Manipulated = itemsController;
            items.CurrentSelection = selection;
            Manipulated.CloneSelected();

            undo.PrepareUndo("Clone",
                Invocation.Create(selection, UndoCloneSelected));

            itemsController.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        void UndoCloneSelected(List<uint> selection)
        {
            Trace.WriteLine("undoCloneSelected:");

            Manipulated = itemsController;
            items.RemoveRange((int)items.Count - selection.Count, selection.Count);
            items.CurrentSelection = selection;

            undo.PrepareUndo("Clone",
                Invocation.Create(selection, RedoCloneSelected));

            itemsController.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        private void deleteToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Trace.WriteLine("deleteSelected:");
            if (Manipulated.SelectedCount <= 0)
                return;

            if (Manipulated == itemsController)
            {
                var currentItems = items.CurrentItems;
                undo.PrepareUndo("Delete",
                    Invocation.Create(currentItems, UndoDeleteSelected));

                Manipulated.RemoveSelected();
            }
            else
            {
                FullMeshAction("Delete", () => Manipulated.RemoveSelected());
            }

            OnEachViewDo(view => view.Invalidate());
        }

        void RedoDeleteSelected(List<IndexedItem> selectedItems)
        {
            Trace.WriteLine("redoDeleteSelected:");

            Manipulated = itemsController;
            items.SetSelectionFromIndexedItems(selectedItems);
            Manipulated.RemoveSelected();

            undo.PrepareUndo("Delete",
                Invocation.Create(selectedItems, UndoDeleteSelected));

            itemsController.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        void UndoDeleteSelected(List<IndexedItem> selectedItems)
        {
            Trace.WriteLine("undoDeleteSelected:");
            Manipulated = itemsController;
            items.CurrentItems = selectedItems;

            undo.PrepareUndo("Delete",
                Invocation.Create(selectedItems, RedoDeleteSelected));

            itemsController.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        private void selectAllToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Manipulated.ChangeSelection(1);
            OnEachViewDo(view => view.Invalidate());
        }

        private void invertSelectionToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Manipulated.InvertSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        private void mergeToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Trace.WriteLine("mergeSelected:");
            if (Manipulated.SelectableCount <= 0)
                return;

            if (Manipulated == itemsController)
            {
                AllItemsAction("Merge", () => items.MergeSelectedItems());
            }
            else
            {
                FullMeshAction("Merge", () => CurrentMesh.MergeSelected());
            }

            Manipulated.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        private void splitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Trace.WriteLine("splitSelected:");
            if (Manipulated.SelectedCount <= 0)
                return;

            if (Manipulated == meshController)
            {
                FullMeshAction("Split", () => CurrentMesh.SplitSelected());
            }

            Manipulated.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        private void flipToolStripMenuItem_Click(object sender, EventArgs e)
        {
            Trace.WriteLine("flipSelected:");
            if (Manipulated.SelectedCount <= 0)
                return;

            if (Manipulated == meshController)
            {
                FullMeshAction("Flip", () => CurrentMesh.FlipSelected());
            }

            Manipulated.UpdateSelection();
            OnEachViewDo(view => view.Invalidate());
        }

        private void mergeVertexPairsToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (Manipulated == meshController)
            {
                CurrentMesh.MergeVertexPairs();
                Manipulated.UpdateSelection();
                OnEachViewDo(view => view.Invalidate());
            }
        }

        private void dropDownEditMode_DropDownItemClicked(object sender, ToolStripItemClickedEventArgs e)
        {
            string tag = e.ClickedItem.Tag.ToString();
            int parsed = int.Parse(tag);
            dropDownEditMode.Text = e.ClickedItem.Text;
            ChangeEditMode((EditMode)parsed);
        }

        private void editToolStripMenuItem_DropDownOpening(object sender, EventArgs e)
        {
            undoToolStripMenuItem.Text = undo.CanUndo ?
                "Undo " + undo.UndoName : "Undo";

            redoToolStripMenuItem.Text = undo.CanRedo ?
                "Redo " + undo.RedoName : "Redo";

            undoToolStripMenuItem.Enabled = undo.CanUndo;
            redoToolStripMenuItem.Enabled = undo.CanRedo;
        }

        #region Splitter magic

        bool ignoreSplitterMoved = true;

        private void splitContainer2_SplitterMoved(object sender, SplitterEventArgs e)
        {
            if (ignoreSplitterMoved)
                return;

            splitContainer3.SplitterDistance = e.SplitX;
            ignoreSplitterMoved = true;
        }

        private void splitContainer3_SplitterMoved(object sender, SplitterEventArgs e)
        {
            if (ignoreSplitterMoved)
                return;

            splitContainer2.SplitterDistance = e.SplitX;
            ignoreSplitterMoved = true;
        }

        private void splitContainer2_SplitterMoving(object sender, SplitterCancelEventArgs e)
        {
            ignoreSplitterMoved = false;
        }

        private void splitContainer3_SplitterMoving(object sender, SplitterCancelEventArgs e)
        {
            ignoreSplitterMoved = false;
        }

        private void oneViewMenuItem_Click(object sender, EventArgs e)
        {
            splitContainer1.Panel1Collapsed = true;
            splitContainer3.Panel1Collapsed = true;
            oneViewMenuItem.Checked = true;
            fourViewsMenuItem.Checked = false;
        }

        private void fourViewsMenuItem_Click(object sender, EventArgs e)
        {
            splitContainer1.Panel1Collapsed = false;
            splitContainer3.Panel1Collapsed = false;
            oneViewMenuItem.Checked = false;
            fourViewsMenuItem.Checked = true;
        }

        #endregion

        #region File menu

        private void newToolStripMenuItem_Click(object sender, EventArgs e)
        {
            items = new ItemCollection();
            itemsController.Model = items;
            itemsController.UpdateSelection();
            undo.Clear();
            OnEachViewDo(view => view.Invalidate());
        }

        private void openToolStripMenuItem_Click(object sender, EventArgs e)
        {
            using (OpenFileDialog dlg = new OpenFileDialog())
            {
                dlg.Filter = fileDialogFilter;
                dlg.RestoreDirectory = true;
                if (dlg.ShowDialog() != DialogResult.OK)
                    return;

                lastFileName = dlg.FileName;
            }

            items = new ItemCollection();
            items.ReadFromFile(lastFileName);
            itemsController.Model = items;
            itemsController.UpdateSelection();
            undo.Clear();
            OnEachViewDo(view => view.Invalidate());
        }

        private void saveToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrEmpty(lastFileName))
            {
                using (SaveFileDialog dlg = new SaveFileDialog())
                {
                    dlg.Filter = fileDialogFilter;
                    dlg.RestoreDirectory = true;
                    if (dlg.ShowDialog() != DialogResult.OK)
                        return;

                    lastFileName = dlg.FileName;
                }
            }
            items.WriteToFile(lastFileName);
            undo.DocumentSaved();
        }

        private void saveAsToolStripMenuItem_Click(object sender, EventArgs e)
        {
            using (SaveFileDialog dlg = new SaveFileDialog())
            {
                dlg.Filter = fileDialogFilter;
                dlg.RestoreDirectory = true;
                if (dlg.ShowDialog() != DialogResult.OK)
                    return;

                lastFileName = dlg.FileName;
            }
            items.WriteToFile(lastFileName);
            undo.DocumentSaved();
        }

        private void exitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            this.Close();
        }

        #endregion
    }
}
