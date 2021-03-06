import os, rdstdin, strutils, times, asynchttpserver, asyncdispatch, packages/docutils/rstgen
from osproc import execCmd
from strformat import `&`

import parsetoml, jester

const
  version = """note version 0.1.0
Copyright (c) 2020 jiro4989
Released under the MIT License.
https://github.com/jiro4989/note"""

let
  configDir = getConfigDir() / "note"
  configBaseName = "config.toml"
  defaultNoteDir = getHomeDir() / "Documents" / "note"

proc getYesterdayFile(dir: string): string =
  for f in walkFiles(dir/"*"):
    result = f

proc createDefaultConfigFile(file: string) =
  let dir = parentDir(file)
  if not existsDir(dir):
    createDir(dir)

  let defaultConfig = &"""
note_dir = "{defaultNoteDir}"
title = ""
editor = "vim"
file_date_prefix = "yyyy-MM-dd"
file_extension = ".md"
copy_from_yesterday_file = false
template_file = "" # relative path from config directory
filter_cmd = "peco"
"""
  writeFile(file, defaultConfig)

proc filterFiles(files: seq[string]): string =
  discard

proc cmdNew(config = configBaseName, title: seq[string]): int =
  let configFile = configDir / config
  if not existsFile(configFile):
    createDefaultConfigFile(configFile)

  let config = parsetoml.parseFile(configFile)

  var title =
    if 1 <= title.len and title[0] != "": title[0]
    else:
      var t = config["title"].getStr()
      if t == "":
        if not readLineFromStdin("Title: ", t): return
      t

  title = title
    .replace(" ", "_")
    .replace("　", "_")
    .replace("\t", "_")
    .replace(":", "")
    .replace(";", "_")

  let
    noteDir = config["note_dir"].getStr()
    datePrefix = config["file_date_prefix"].getStr()
    ext = config["file_extension"].getStr()
    editor = config["editor"].getStr()
    prefix =
      if datePrefix != "": now().format(datePrefix) & "_"
      else: ""
    copyFromYesterdayFile = config["copy_from_yesterday_file"].getBool()
    noteBaseName = prefix & title & ext
    noteFile = noteDir / noteBaseName
    templateBaseName = config["template_file"].getStr()

  if not existsDir(noteDir):
    createDir(noteDir)

  if copyFromYesterdayFile:
    let yesterdayFile = getYesterdayFile(noteDir)
    if yesterdayFile != "" and yesterdayFile != noteFile:
      copyFile(yesterdayFile, noteFile)

  if not existsFile(noteFile) and templateBaseName != "":
    let templateFile = configDir / templateBaseName
    let body = readFile(templateFile)
    writeFile(noteFile, body)

  discard execCmd(editor & " " & noteFile)
  echo noteFile

proc cmdEdit(config = configBaseName, filterDaysAgo = -1, files: seq[string]): int =
  let file =
    if files.len < 1: ""
    else: files[0]
  let
    configFile = configDir / config
    config = parsetoml.parseFile(configFile)
    noteDir = config["note_dir"].getStr()
    editor = config["editor"].getStr()
    noteFile = noteDir / file
  discard execCmd(editor & " " & noteFile)
  echo noteFile

proc cmdConfig(config = configBaseName): int =
  let configFile = configDir / config
  if not existsFile(configFile):
    createDefaultConfigFile(configFile)

  let
    config = parsetoml.parseFile(configFile)
    editor = config["editor"].getStr()
  discard execCmd(editor & " " & configFile)
  echo configFile

var serverConfig: string
router myrouter:
  get "/":
    let
      configFile = configDir / serverConfig
      config = parsetoml.parseFile(configFile)
      noteDir = config["note_dir"].getStr()
    var links: seq[string]
    for f in walkFiles(noteDir/"*"):
      let (_, base, ext) = splitFile(f)
      let baseName = base & ext
      let link = &"""<a href="/{baseName}">{baseName}</a>"""
      links.add(link)
    resp links.join("<br />")
  get "/@file":
    let
      baseName = @"file"
      configFile = configDir / serverConfig
      config = parsetoml.parseFile(configFile)
      noteDir = config["note_dir"].getStr()
      noteFile = noteDir / baseName
      bodyText = readFile(noteFile)
      bodyHtml = rstToHtml(bodyText, {}, newStringTable(modeStyleInsensitive))
    resp bodyHtml

proc cmdServer(config = configBaseName): int =
  serverConfig = config
  let port = 8080
  var settings = newSettings(port = Port(port))
  var jester = initJester(myrouter, settings = settings)
  echo "http://localhost:" & $port
  jester.serve()

proc cmdInfo(): int =
  ## print information.
  let configFile = configDir / configBaseName
  echo &"config directory: {configDir}"
  echo &"default config file: {configFile}"
  echo &"default note directory: {defaultNoteDir}"

when isMainModule:
  import cligen
  clCfg.version = version
  dispatchMulti([cmdNew, cmdName="new"],
                [cmdEdit, cmdName="edit"],
                [cmdConfig, cmdName="config"],
                [cmdServer, cmdName="server"],
                [cmdInfo, cmdName="info"],
  )
