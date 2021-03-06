path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
FountainPreviewView = require '../lib/fountain-preview-view'

describe "FountainPreviewView", ->
  [file, preview, workspaceElement] = []

  beforeEach ->
    filePath = atom.project.resolve('subdir/file.fountain')
    preview = new FountainPreviewView({filePath})
    jasmine.attachToDOM(preview.element)

    waitsForPromise ->
      atom.packages.activatePackage('language-ruby')

    waitsForPromise ->
      atom.packages.activatePackage('fountain-preview')

  afterEach ->
    preview.destroy()

  describe "::constructor", ->
    it "shows a loading spinner and renders the fountain", ->
      preview.showLoading()
      expect(preview.find('.fountain-spinner')).toExist()

      waitsForPromise ->
        preview.renderFountain()

      runs ->
        expect(preview.find(".emoji")).toExist()

    it "shows an error message when there is an error", ->
      preview.showError("Not a real file")
      expect(preview.text()).toContain "Failed"

  describe "serialization", ->
    newPreview = null

    afterEach ->
      newPreview.destroy()

    it "recreates the file when serialized/deserialized", ->
      newPreview = atom.deserializers.deserialize(preview.serialize())
      jasmine.attachToDOM(newPreview.element)
      expect(newPreview.getPath()).toBe preview.getPath()

    it "serializes the editor id when opened for an editor", ->
      preview.destroy()

      waitsForPromise ->
        atom.workspace.open('new.fountain')

      runs ->
        preview = new FountainPreviewView({editorId: atom.workspace.getActiveTextEditor().id})

        jasmine.attachToDOM(preview.element)
        expect(preview.getPath()).toBe atom.workspace.getActiveTextEditor().getPath()

        newPreview = atom.deserializers.deserialize(preview.serialize())
        jasmine.attachToDOM(newPreview.element)
        expect(newPreview.getPath()).toBe preview.getPath()

  describe "code block tokenization", ->
    beforeEach ->
      waitsForPromise ->
        preview.renderFountain()

    describe "when the code block's fence name has a matching grammar", ->
      it "tokenizes the code block with the grammar", ->
        expect(preview.find("pre span.entity.name.function.ruby")).toExist()

    describe "when the code block's fence name doesn't have a matching grammar", ->
      it "does not tokenize the code block", ->
        expect(preview.find("pre.lang-kombucha .line .null-grammar").children().length).toBe 2

    describe "when the code block contains empty lines", ->
      it "doesn't remove the empty lines", ->
        expect(preview.find("pre.lang-python").children().length).toBe 6
        expect(preview.find("pre.lang-python div:nth-child(2)").text().trim()).toBe ''
        expect(preview.find("pre.lang-python div:nth-child(4)").text().trim()).toBe ''
        expect(preview.find("pre.lang-python div:nth-child(5)").text().trim()).toBe ''

    describe "when the code block is nested", ->
      it "detects and styles the block", ->
        expect(preview.find("pre.lang-javascript")).toHaveClass 'editor-colors'

  describe "image resolving", ->
    beforeEach ->
      waitsForPromise ->
        preview.renderFountain()

    describe "when the image uses a relative path", ->
      it "resolves to a path relative to the file", ->
        image = preview.find("img[alt=Image1]")
        expect(image.attr('src')).toBe atom.project.resolve('subdir/image1.png')

    describe "when the image uses an absolute path that does not exist", ->
      it "resolves to a path relative to the project root", ->
        image = preview.find("img[alt=Image2]")
        expect(image.attr('src')).toBe atom.project.resolve('tmp/image2.png')

    describe "when the image uses an absolute path that exists", ->
      it "doesn't change the URL", ->
        preview.destroy()

        filePath = path.join(temp.mkdirSync('atom'), 'foo.md')
        fs.writeFileSync(filePath, "![absolute](#{filePath})")
        preview = new FountainPreviewView({filePath})
        jasmine.attachToDOM(preview.element)

        waitsForPromise ->
          preview.renderFountain()

        runs ->
          expect(preview.find("img[alt=absolute]").attr('src')).toBe filePath

    describe "when the image uses a web URL", ->
      it "doesn't change the URL", ->
        image = preview.find("img[alt=Image3]")
        expect(image.attr('src')).toBe 'http://github.com/image3.png'

  describe "gfm newlines", ->
    describe "when gfm newlines are not enabled", ->
      it "creates a single paragraph with <br>", ->
        atom.config.set('fountain-preview.breakOnSingleNewline', false)

        waitsForPromise ->
          preview.renderFountain()

        runs ->
          expect(preview.find("p:last-child br").length).toBe 0

    describe "when gfm newlines are enabled", ->
      it "creates a single paragraph with no <br>", ->
        atom.config.set('fountain-preview.breakOnSingleNewline', true)

        waitsForPromise ->
          preview.renderFountain()

        runs ->
          expect(preview.find("p:last-child br").length).toBe 1

  describe "when core:save-as is triggered", ->
    beforeEach ->
      preview.destroy()
      filePath = atom.project.resolve('subdir/simple.md')
      preview = new FountainPreviewView({filePath})
      jasmine.attachToDOM(preview.element)

    it "saves the rendered HTML and opens it", ->
      outputPath = temp.path(suffix: '.html')
      expect(fs.isFileSync(outputPath)).toBe false

      waitsForPromise ->
        preview.renderFountain()

      runs ->
        spyOn(atom, 'showSaveDialogSync').andReturn(outputPath)
        atom.commands.dispatch preview.element, 'core:save-as'
        outputPath = fs.realpathSync(outputPath)
        expect(fs.isFileSync(outputPath)).toBe true

      waitsFor ->
        atom.workspace.getActiveTextEditor()?.getPath() is outputPath

      runs ->
        expect(atom.workspace.getActiveTextEditor().getText()).toBe """
          <p><em>italic</em></p>
          <p><strong>bold</strong></p>
          <p>encoding \u2192 issue</p>
        """

  describe "when core:copy is triggered", ->
    beforeEach ->
      preview.destroy()
      filePath = atom.project.resolve('subdir/simple.md')
      preview = new FountainPreviewView({filePath})
      jasmine.attachToDOM(preview.element)

    it "writes the rendered HTML to the clipboard", ->
      waitsForPromise ->
        preview.renderFountain()

      runs ->
        atom.commands.dispatch preview.element, 'core:copy'
        expect(atom.clipboard.read()).toBe """
          <p><em>italic</em></p>
          <p><strong>bold</strong></p>
          <p>encoding \u2192 issue</p>
        """
