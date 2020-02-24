import os, rdstdin, strutils, times
from osproc import execCmd
from strformat import `&`

import parsetoml

const
  version = """note version 0.1.0
Copyright (c) 2020 jiro4989
Released under the MIT License.
https://github.com/jiro4989/note"""

let
  configDir = getConfigDir() / "note"
  configBaseName = "config.toml"
  defaultNoteDir = getHomeDir() / "Documents" / "note"

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
copy_from_recently_file = false
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

  let
    config = parsetoml.parseFile(configFile)

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
      if datePrefix != "":
        now().format(datePrefix) & "_"
      else: ""
    noteFile = noteDir / prefix & title & ext
    templateFile = configDir / config["template_file"].getStr()

  if not existsDir(noteDir):
    createDir(noteDir)
  if not existsFile(noteFile) and templateFile != "":
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

proc cmdServer(): int =
  discard

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
