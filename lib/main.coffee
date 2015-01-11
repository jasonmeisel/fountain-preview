url = require 'url'
fs = require 'fs-plus'
{$} = require 'atom-space-pen-views'

FountainPreviewView = null # Defer until used
renderer = null # Defer until used

createFountainPreviewView = (state) ->
  FountainPreviewView ?= require './fountain-preview-view'
  new FountainPreviewView(state)

isFountainPreviewView = (object) ->
  FountainPreviewView ?= require './fountain-preview-view'
  object instanceof FountainPreviewView

atom.deserializers.add
  name: 'FountainPreviewView'
  deserialize: (state) ->
    createFountainPreviewView(state) if state.constructor is Object

module.exports =
  config:
    breakOnSingleNewline:
      type: 'boolean'
      default: false
    liveUpdate:
      type: 'boolean'
      default: true
    grammars:
      type: 'array'
      default: [
        'source.gfm'
        'source.litcoffee'
        'text.html.basic'
        'text.plain'
        'text.plain.null-grammar'
      ]

  activate: ->
    atom.commands.add 'atom-workspace',
      'fountain-preview:toggle': =>
        @toggle()
      'fountain-preview:copy-html': =>
        @copyHtml()
      'fountain-preview:toggle-break-on-single-newline': ->
        keyPath = 'fountain-preview.breakOnSingleNewline'
        atom.config.set(keyPath, !atom.config.get(keyPath))

    previewFile = @previewFile.bind(this)
    atom.commands.add '.tree-view .file .name[data-name$=\\.md]', 'fountain-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mdown]', 'fountain-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkd]', 'fountain-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkdown]', 'fountain-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.ron]', 'fountain-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.text]', 'fountain-preview:preview-file', previewFile

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'fountain-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createFountainPreviewView(editorId: pathname.substring(1))
      else
        createFountainPreviewView(filePath: pathname)

  toggle: ->
    if isFountainPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('fountain-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "fountain-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForUri(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForUri(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (fountainPreviewView) ->
      if isFountainPreviewView(fountainPreviewView)
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "fountain-preview://#{encodeURI(filePath)}", searchAllPanes: true

  copyHtml: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    renderer ?= require './renderer'
    text = editor.getSelectedText() or editor.getText()
    renderer.toText text, editor.getPath(), editor.getGrammar(), (error, html) =>
      if error
        console.warn('Copying Fountain as HTML failed', error)
      else
        atom.clipboard.write(html)
