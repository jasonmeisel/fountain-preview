path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'
FountainPreviewView = require '../lib/fountain-preview-view'

describe "Fountain preview package", ->
  workspaceElement = null

  beforeEach ->
    fixturesPath = path.join(__dirname, 'fixtures')
    tempPath = temp.mkdirSync('atom')
    wrench.copyDirSyncRecursive(fixturesPath, tempPath, forceDelete: true)
    atom.project.setPaths([tempPath])
    jasmine.unspy(window, 'setTimeout')

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)

    spyOn(FountainPreviewView.prototype, 'renderFountain').andCallThrough()

    waitsForPromise ->
      atom.packages.activatePackage("fountain-preview")

    waitsForPromise ->
      atom.packages.activatePackage('language-gfm')

  describe "when a preview has not been created for the file", ->
    it "splits the current pane to the right with a fountain preview for the file", ->
      waitsForPromise ->
        atom.workspace.open("subdir/file.fountain")

      runs ->
        atom.commands.dispatch atom.views.getView(atom.workspace.getActivePaneItem()), 'fountain-preview:toggle'

      waitsFor ->
        FountainPreviewView::renderFountain.callCount > 0

      runs ->
        expect(atom.workspace.getPanes()).toHaveLength 2
        [editorPane, previewPane] = atom.workspace.getPanes()

        expect(editorPane.getItems()).toHaveLength 1
        preview = previewPane.getActiveItem()
        expect(preview).toBeInstanceOf(FountainPreviewView)
        expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
        expect(editorPane.isActive()).toBe true

    describe "when the editor's path does not exist", ->
      it "splits the current pane to the right with a fountain preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("new.fountain")

        runs ->
          atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

        waitsFor ->
          FountainPreviewView::renderFountain.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(FountainPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

    describe "when the editor does not have a path", ->
      it "splits the current pane to the right with a fountain preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("")

        runs ->
          atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

        waitsFor ->
          FountainPreviewView::renderFountain.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(FountainPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

    describe "when the path contains a space", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/file with space.md")

        runs ->
          atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

        waitsFor ->
          FountainPreviewView::renderFountain.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(FountainPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

    describe "when the path contains accented characters", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/áccéntéd.md")

        runs ->
          atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

        waitsFor ->
          FountainPreviewView::renderFountain.callCount > 0

        runs ->
          expect(atom.workspace.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspace.getPanes()

          expect(editorPane.getItems()).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(FountainPreviewView)
          expect(preview.getPath()).toBe atom.workspace.getActivePaneItem().getPath()
          expect(editorPane.isActive()).toBe true

  describe "when a preview has been created for the file", ->
    [editorPane, previewPane, preview] = []

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open("subdir/file.fountain")

      runs ->
        atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

      waitsFor ->
        FountainPreviewView::renderFountain.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        FountainPreviewView::renderFountain.reset()

    it "closes the existing preview when toggle is triggered a second time on the editor", ->
      atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

      [editorPane, previewPane] = atom.workspace.getPanes()
      expect(editorPane.isActive()).toBe true
      expect(previewPane.getActiveItem()).toBeUndefined()

    it "closes the existing preview when toggle is triggered on it and it has focus", ->
      previewPane.activate()
      atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

      [editorPane, previewPane] = atom.workspace.getPanes()
      expect(previewPane.getActiveItem()).toBeUndefined()

    describe "when the editor is modified", ->
      it "invokes ::onDidChangeFountain listeners", ->
        fountainEditor = atom.workspace.getActiveTextEditor()
        preview = previewPane.getActiveItem()
        preview.onDidChangeFountain(listener = jasmine.createSpy('didChangeFountainListener'))

        runs ->
          FountainPreviewView::renderFountain.reset()
          fountainEditor.setText("Hey!")

        waitsFor ->
          FountainPreviewView::renderFountain.callCount > 0

        runs ->
          expect(listener).toHaveBeenCalled()

      describe "when the preview is in the active pane but is not the active item", ->
        it "re-renders the preview but does not make it active", ->
          fountainEditor = atom.workspace.getActiveTextEditor()
          previewPane.activate()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            FountainPreviewView::renderFountain.reset()
            fountainEditor.setText("Hey!")

          waitsFor ->
            FountainPreviewView::renderFountain.callCount > 0

          runs ->
            expect(previewPane.isActive()).toBe true
            expect(previewPane.getActiveItem()).not.toBe preview

      describe "when the preview is not the active item and not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          fountainEditor = atom.workspace.getActiveTextEditor()
          previewPane.splitRight(copyActiveItem: true)
          previewPane.activate()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            FountainPreviewView::renderFountain.reset()
            editorPane.activate()
            fountainEditor.setText("Hey!")

          waitsFor ->
            FountainPreviewView::renderFountain.callCount > 0

          runs ->
            expect(editorPane.isActive()).toBe true
            expect(previewPane.getActiveItem()).toBe preview

      describe "when the liveUpdate config is set to false", ->
        it "only re-renders the fountain when the editor is saved, not when the contents are modified", ->
          atom.config.set 'fountain-preview.liveUpdate', false

          didStopChangingHandler = jasmine.createSpy('didStopChangingHandler')
          atom.workspace.getActiveTextEditor().getBuffer().onDidStopChanging didStopChangingHandler
          atom.workspace.getActiveTextEditor().setText('ch ch changes')

          waitsFor ->
            didStopChangingHandler.callCount > 0

          runs ->
            expect(FountainPreviewView::renderFountain.callCount).toBe 0
            atom.workspace.getActiveTextEditor().save()
            expect(FountainPreviewView::renderFountain.callCount).toBe 1

    describe "when a new grammar is loaded", ->
      it "re-renders the preview", ->
        waitsForPromise ->
          atom.packages.activatePackage('language-javascript')

        waitsFor ->
          FountainPreviewView::renderFountain.callCount > 0

  describe "when the fountain preview view is requested by file URI", ->
    it "opens a preview editor and watches the file for changes", ->
      waitsForPromise "atom.workspace.open promise to be resolved", ->
        atom.workspace.open("fountain-preview://#{atom.project.resolve('subdir/file.fountain')}")

      runs ->
        expect(FountainPreviewView::renderFountain.callCount).toBeGreaterThan 0
        preview = atom.workspace.getActivePaneItem()
        expect(preview).toBeInstanceOf(FountainPreviewView)

        FountainPreviewView::renderFountain.reset()
        preview.file.emitter.emit('did-change')

      waitsFor "renderFountain to be called", ->
        FountainPreviewView::renderFountain.callCount > 0

  describe "when the editor's grammar it not enabled for preview", ->
    it "does not open the fountain preview", ->
      atom.config.set('fountain-preview.grammars', [])

      waitsForPromise ->
        atom.workspace.open("subdir/file.fountain")

      runs ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'
        expect(atom.workspace.open).not.toHaveBeenCalled()

  describe "when the editor's path changes on #win32 and #darwin", ->
    it "updates the preview's title", ->
      titleChangedCallback = jasmine.createSpy('titleChangedCallback')

      waitsForPromise ->
        atom.workspace.open("subdir/file.fountain")

      runs ->
        atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

      waitsFor ->
        FountainPreviewView::renderFountain.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview.getTitle()).toBe 'file.fountain Preview'

        titleChangedCallback.reset()
        preview.onDidChangeTitle(titleChangedCallback)
        fs.renameSync(atom.workspace.getActiveTextEditor().getPath(), path.join(path.dirname(atom.workspace.getActiveTextEditor().getPath()), 'file2.md'))

      waitsFor ->
        titleChangedCallback.callCount is 1

  describe "when the URI opened does not have a fountain-preview protocol", ->
    it "does not throw an error trying to decode the URI (regression)", ->
      waitsForPromise ->
        atom.workspace.open('%')

      runs ->
        expect(atom.workspace.getActiveTextEditor()).toBeTruthy()

  describe "when fountain-preview:copy-html is triggered", ->
    it "copies the HTML to the clipboard", ->
      waitsForPromise ->
        atom.workspace.open("subdir/simple.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'fountain-preview:copy-html'
        expect(atom.clipboard.read()).toBe """
          <p><em>italic</em></p>
          <p><strong>bold</strong></p>
          <p>encoding \u2192 issue</p>
        """

        atom.workspace.getActiveTextEditor().setSelectedBufferRange [[0, 0], [1, 0]]
        atom.commands.dispatch workspaceElement, 'fountain-preview:copy-html'
        expect(atom.clipboard.read()).toBe """
          <p><em>italic</em></p>
        """

  describe "sanitization", ->
    it "removes script tags and attributes that commonly contain inline scripts", ->
      waitsForPromise ->
        atom.workspace.open("subdir/evil.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

      waitsFor ->
        FountainPreviewView::renderFountain.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview[0].innerHTML).toBe """
          <p>hello</p>
          <p></p>
          <p>
          <img>
          world</p>
        """

    it "remove the first <!doctype> tag at the beginning of the file", ->
      waitsForPromise ->
        atom.workspace.open("subdir/doctype-tag.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

      waitsFor ->
        FountainPreviewView::renderFountain.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview[0].innerHTML).toBe """
          <p>content
          &lt;!doctype html&gt;</p>
        """

  describe "when the fountain contains an <html> tag", ->
    it "does not throw an exception", ->
      waitsForPromise ->
        atom.workspace.open("subdir/html-tag.md")

      runs ->
        atom.commands.dispatch workspaceElement, 'fountain-preview:toggle'

      waitsFor ->
        FountainPreviewView::renderFountain.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspace.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview[0].innerHTML).toBe "content"
