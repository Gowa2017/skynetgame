#encoding=utf-8
'''
Copyright YANG Huan (sy.yanghuan@gmail.com)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
'''
import sys        

if sys.version_info < (3, 0):
  print('python version need more than 3.x')
  sys.exit(1)
    
import os
import string
import collections
import codecs
import getopt
import re
import json
import traceback
import multiprocessing
import xml.etree.ElementTree as ElementTree
import xml.dom.minidom as minidom
import sxl

def fillvalue(parent, name, value, isschema):
  if isinstance(parent, list):
    parent.append(value) 
  else:
    if isschema and not re.match('^_|[a-zA-Z]\w*$', name):
      raise ValueError('%s is a illegal identifier' % name)
    parent[name] = value
    
def getindex(infos, name):
  return next((i for i, j in enumerate(infos) if j == name), -1)
  
def getcellvalue(value):
  return str(value) if value is not None else ''

def getscemainfo(typename, description):
  if isinstance(typename, BindType):
    typename = typename.typename
  return [typename, description] if description else [typename]
        
def getexportmark(sheetName):
  p = re.search('\|[' + string.whitespace + ']*(_|[a-zA-Z]\w+)', sheetName)
  return p.group(1) if p else False

def issignmatch(signarg, sign):
  if signarg is None:
    return True
  return True if [s for s in re.split(r'[/\\, :]', sign) if s in signarg] else False

def isoutofdate(srcfile, tarfile):
  return not os.path.isfile(tarfile) or os.path.getmtime(srcfile) > os.path.getmtime(tarfile)

def gerexportfilename(root, format_, folder):
  filename = root +  '.' + format_
  return os.path.join(folder, filename)

def splitspace(s):
  return re.split(r'[' + string.whitespace + ']+', s.strip())
  
def buildbasexml(parent, name, value):
  value = str(value)
  if parent.tag == name + 's':
    element = ElementTree.Element(name)
    element.text = value
    parent.append(element)
  else:
    parent.set(name, value)
            
def buildlistxml(parent, name, list_):
  element = ElementTree.Element(name)
  parent.append(element)
  for v in list_:
    buildxml(element, name[:-1], v)    

def buildobjxml(parent, name, obj):
  element = ElementTree.Element(name)
  parent.append(element)
  
  for k, v in obj.items():
    buildxml(element, k, v)
        
def buildxml(parent, name, value):
  if isinstance(value, int) or isinstance(value, float) or isinstance(value, str):
    buildbasexml(parent, name, value)
      
  elif isinstance(value, list):
    buildlistxml(parent, name, value)
      
  elif isinstance(value, dict):
    buildobjxml(parent, name, value)
            
def savexml(record):
  book = ElementTree.ElementTree()
  book.append = lambda e: book._setroot(e)
  buildxml(book, record.root, record.obj)
  
  xmlstr = ElementTree.tostring(book.getroot(), 'utf-8')
  dom = minidom.parseString(xmlstr)
  with codecs.open(record.exportfile, 'w', 'utf-8') as f:
    dom.writexml(f, '', '  ', '\n', 'utf-8')
      
  print('save %s from %s in %s' % (record.exportfile, record.sheet.name, record.path))
  
def newline(count):
  return '\n' + '  ' * count
  
def tolua(obj, indent = 1):    
  if isinstance(obj, int) or isinstance(obj, float) or isinstance(obj, str):
    yield json.dumps(obj, ensure_ascii = False)
  else:
    yield '{'
    islist = isinstance(obj, list)
    isfirst = True
    for i in obj:
      if isfirst:
        isfirst = False
      else:
        yield ','
      yield newline(indent)
      if not islist:
        k = i
        i = obj[k]
        yield k 
        yield ' = '                
      for part in tolua(i, indent + 1):
        yield part
    yield newline(indent - 1)
    yield '}'
    
def toycl(obj, indent = 0):
  islist = isinstance(obj, list)
  for i in obj:
    yield newline(indent)  
    if not islist:
      k = i
      i = obj[k]
      yield k 
    if isinstance(i, int) or isinstance(i, float) or isinstance(i, str): 
      if not islist:
        yield ' = '
      yield json.dumps(i, ensure_ascii = False)
    else:
      if not islist:
        yield ' '
      yield '{'
      for part in toycl(i, indent + 1):
        yield part
      yield newline(indent)  
      yield '}'     

class BindType:
  def __init__(self, type_):
    self.typename = type_
      
  def __eq__(self, other):
    return self.typename == other
    
class Record:
  def __init__(self, path, sheet, exportfile, root, item, obj, exportmark):
    self.path = path 
    self.sheet = sheet 
    self.exportfile = exportfile 
    self.root = root 
    self.item = item
    self.setobj(obj)
    self.exportmark = exportmark

  def setobj(self, obj):    
    self.schema = obj[0] if obj else None
    self.obj = obj[1] if obj else None
        
class Constraint:
  def __init__(self, mark, filed):
    self.mark = mark
    self.field = filed     
        
class Exporter:
  configsheettitles = ('name', 'value', 'type', 'sign', 'description')
  spacemaxrowcount = 3
  
  def __init__(self, context):
    self.context = context
    self.records = []
    
  def checkstringescape(self, t, v):
    return v if not v or not 'string' in t else v.replace('\\n', '\n').replace('\,', '\0').replace('\\' + self.context.objseparator, '\a')
  
  def stringescape(self, s):
    return s.replace('\0', ',').replace('\a', self.context.objseparator)
  
  def gettype(self, type_):
    if type_[-2] == '[' and  type_[-1] == ']':
      return 'list'
    if type_[0] == '{' and type_[-1] == '}':
      return 'obj'
    if type_ in ('int', 'double', 'string', 'bool', 'long', 'float'):
      return type_
    
    p = re.search('(int|string|long)[' + string.whitespace + ']*\((\S+)\.(\S+)\)', type_)
    if p:
      type_ = BindType(p.group(1))
      type_.mark = p.group(2)
      type_.field = p.group(3)
      return type_
        
    raise ValueError('%s is not a legal type' % type_)
    
  def buildlistexpress(self, parent, type_, name, value, isschema):
    basetype = type_[:-2]
    list_ = []
    if isschema:
      self.buildexpress(list_, basetype, name, None, isschema)
      list_ = getscemainfo(list_[0], value)
    else:
      valuelist = value.strip('[]').split(',')
      for v in valuelist:
        self.buildexpress(list_, basetype, name, v)
       
    fillvalue(parent, name + 's', list_, isschema)
      
  def buildobjexpress(self, parent, type_, name, value, isschema):
    obj = collections.OrderedDict()
    fieldnamestypes = type_.strip('{}').split(self.context.objseparator)
    
    if isschema:
      for i in range(0, len(fieldnamestypes)):
        fieldtype, fieldname = splitspace(fieldnamestypes[i])
        self.buildexpress(obj, fieldtype, fieldname, None, isschema)
      obj = getscemainfo(obj, value)
    else:
      fieldValues = value.strip('{}').split(self.context.objseparator)
      for i in range(0, len(fieldnamestypes)):
        if i < len(fieldValues):
          fieldtype, fieldname = splitspace(fieldnamestypes[i])
          self.buildexpress(obj, fieldtype, fieldname, fieldValues[i])

    fillvalue(parent, name, obj, isschema)       
      
  def buildbasexpress(self, parent, type_, name, value, isschema):
    typename = self.gettype(type_) 
    if isschema:
      value = getscemainfo(typename, value)
    else:
      if typename != 'string' and value.isspace():
        return
        
      if typename == 'int' or typename == 'long':
        value = int(float(value))
      elif typename == 'double' or typename == 'float':
        value = float(value)   
      elif typename == 'string':
        if value.endswith('.0'):          # may read is like "123.0"
          try:
            value = str(int(float(value)))
          except ValueError:
            value = self.stringescape(str(value))
        else:            
          value = self.stringescape(str(value))
      elif typename == 'bool':
        try:
          value = int(float(value))
          value = False if value == 0 else True 
        except ValueError:
          value = value.lower() 
          if value in ('false', 'no', 'off'):
            value = False
          elif value in ('true', 'yes', 'on'):
            value = True
          else:
            raise ValueError('%s is a illegal bool value' % value)
            
    fillvalue(parent, name, value, isschema)

  def buildexpress(self, parent, type_, name, value, isschema = False):
    typename = self.gettype(type_)
    if typename == 'list':
      self.buildlistexpress(parent, type_, name, value, isschema)
    elif typename == 'obj':
      self.buildobjexpress(parent, type_, name, value, isschema)
    else:
      self.buildbasexpress(parent, type_, name, value, isschema)
      
  def getrootname(self, exportmark, isitem):
    return exportmark + 's' + (self.context.extension or '') if isitem else exportmark + (self.context.extension or '')

  def export(self, path):
    self.path = path
    data = sxl.Workbook(self.path)
    cout = None

    for sheetname in [i for i in data.sheets if type(i) is str]:
      self.sheetname = sheetname
      exportmark = getexportmark(sheetname)
      if exportmark:
        sheet = data.sheets[sheetname]
        coutmark = sheetname.endswith('<<')
        configtitleinfo = self.getconfigsheetfinfo(sheet)
        if not configtitleinfo:
          root = self.getrootname(exportmark, not coutmark)
          item = exportmark
        else:
          root = self.getrootname(exportmark, False)
          item = None
          
        if not cout:  
          self.checksheetname(self.path, sheetname, root)
          exportfile = gerexportfilename(root, self.context.format, self.context.folder)
          
          if isoutofdate(self.path, exportfile):
            if item:
              exportobj = self.exportitemsheet(sheet)
            else:
              exportobj = self.exportconfigsheet(sheet, configtitleinfo)
          
            if coutmark:
              if not item:
                cout = exportobj
              else:
                cout = (collections.OrderedDict(), collections.OrderedDict())
                cout[0][item + 's'] = [[exportobj[0]]]
                item = None
                exportobj = cout
                obj = exportobj[1]
                if obj:
                  cout[1][item + 's'] = obj
                  
            self.records.append(Record(self.path, sheet, exportfile, root, item, exportobj, exportmark))
          else:
            print('%s is not changed' % (self.path))
            break
        else:
          if item:
            exportobj = self.exportitemsheet(sheet)
            cout[0][item + 's'] = [[exportobj[0]]]
            obj = exportobj[1]
            if obj:
              cout[1][item + 's'] = obj
          else:
            exportobj = self.exportconfigsheet(sheet, configtitleinfo)
            cout[0].update(exportobj[0])   
            obj = exportobj[1]
            if obj:
              cout[1].update(obj)
              
    return self.saves()

  def getconfigsheetfinfo(self, sheet):
    titles = sheet.head(1)[0]
    
    nameindex = getindex(titles, self.configsheettitles[0])
    valueindex = getindex(titles, self.configsheettitles[1])
    typeindex = getindex(titles, self.configsheettitles[2])
    signindex = getindex(titles, self.configsheettitles[3])
    descriptionindex = getindex(titles, self.configsheettitles[4])
    
    if nameindex != -1 and valueindex != -1 and typeindex != -1:
      return (nameindex, valueindex, typeindex, signindex, descriptionindex)
    else:
      return None
      
  def exportitemsheet(self, sheet):
    rows = iter(sheet.rows)
    descriptions = next(rows)
    types = next(rows)
    names = next(rows)
    signs = next(rows)
    
    ncols = len(types)
    titleinfos = []
    schemaobj = collections.OrderedDict()
    
    try:
      for colindex in range(ncols):
        type_ = getcellvalue(types[colindex]).strip()
        name = getcellvalue(names[colindex]).strip()
        signmatch = issignmatch(self.context.sign, getcellvalue(signs[colindex]).strip())        
        titleinfos.append((type_, name, signmatch))
        
        if self.context.codegenerator:
          if type_ and name and signmatch:
            self.buildexpress(schemaobj, type_, name, descriptions[colindex], True)
            
    except Exception as e:
      e.args += ('%s has a title error, %s at %d column in %s' % (sheet.name, (type_, name), colindex + 1, self.path) , '')
      raise e
      
    list_ = []
    hasexport = next((i for i in titleinfos if i[0] and i[1] and i[2]), False)
    if hasexport:
      try:
        spacerowcount = 0
        self.rowindex = 3
        for row in rows:
          self.rowindex += 1
          
          item = collections.OrderedDict()
          firsttext = getcellvalue(row[0]).strip()
          if not firsttext:
            spacerowcount += 1
            if spacerowcount >= self.spacemaxrowcount:      # if space row is than max count, skil follow rows     
              break
          
          if not firsttext or firsttext[0] == '#':    # current line skip
            continue
            
          skiptokenindex = None
          if firsttext[0] == '!':
            nextpos = firsttext.find('!', 1)
            if nextpos >= 2:
              signtoken = firsttext[1: nextpos]
              if issignmatch(self.context.sign, signtoken.strip()):
                continue
              else:
                skiptokenindex = len(signtoken) + 2
          
          for self.colindex in range(ncols):
            signmatch = titleinfos[self.colindex][2]
            if signmatch:
              type_ = titleinfos[self.colindex][0]
              name = titleinfos[self.colindex][1]
              value = getcellvalue(row[self.colindex])
              
              if skiptokenindex and self.colindex == 0:
                value = value.lstrip()[skiptokenindex:]
                
              if type_ and name and value:
                self.buildexpress(item, type_, name, self.checkstringescape(type_, value))  
            spacerowcount = 0
            
          if item:
            list_.append(item) 
          
      except Exception as e:        
          e.args += ('%s has a error in %d row %d(%s) column in %s' % (sheet.name, self.rowindex + 1, self.colindex + 1, name, self.path) , '')
          raise e
    
    return (schemaobj, list_)
        
  def exportconfigsheet(self, sheet, titleindexs):
    rows = iter(sheet.rows)
    next(rows)
  
    nameindex = titleindexs[0]
    valueindex = titleindexs[1]
    typeindex = titleindexs[2]
    signindex = titleindexs[3]
    descriptionindex = titleindexs[4]
    
    schemaobj = collections.OrderedDict()
    obj = collections.OrderedDict()
    
    try:
      spacerowcount = 0
      self.rowindex = 0
      for row in rows:
        self.rowindex += 1
        name = getcellvalue(row[nameindex]).strip()
        value = getcellvalue(row[valueindex])
        type_ = getcellvalue(row[typeindex]).strip()
        description = getcellvalue(row[descriptionindex]).strip()
        
        if signindex > 0:
          sign = getcellvalue(row[signindex]).strip()
          if not issignmatch(self.context.sign, sign):
            continue
          
        if not name and not value and not type_:
          spacerowcount += 1
          if spacerowcount >= self.spacemaxrowcount:
            break            # if space row is than max count, skil follow rows     
          continue
            
        if name and type_:
          if(name[0] != '#'):         # current line skip
            if self.context.codegenerator:
              self.buildexpress(schemaobj, type_, name, description, True)
            if value:    
              self.buildexpress(obj, type_, name, self.checkstringescape(type_, value))
          spacerowcount = 0    
               
    except Exception as e:
      e.args += ('%s has a error in %d row (%s, %s, %s) in %s' % (sheet.name, self.rowindex + 1, type_, name, value, self.path) , '')
      raise e
  
    return (schemaobj, obj)
    
  def saves(self):
    schemas = []
    for r in self.records:
      if r.obj:
        self.save(r)

        if self.context.codegenerator:        # has code generator
          schemas.append({ 'path': r.path, 'exportfile' : r.exportfile, 'root' : r.root, 'item' : r.item or r.exportmark, 'schema' : r.schema })

    return schemas
                
  def save(self, record):
    if not record.obj:
      return
  
    if not os.path.isdir(self.context.folder):
      os.makedirs(self.context.folder)
        
    if self.context.format == 'json':
      jsonstr = json.dumps(record.obj, ensure_ascii = False, indent = 2)
      with codecs.open(record.exportfile, 'w', 'utf-8') as f:
        f.write(jsonstr)
      print('save %s from %s in %s' % (record.exportfile, record.sheet.name, record.path))
        
    elif self.context.format == 'xml':
      if record.item:
        record.obj = { record.item + 's' : record.obj }
      savexml(record) 
        
    elif self.context.format == 'lua':
      luastr = "".join(tolua(record.obj))
      with codecs.open(record.exportfile, 'w', 'utf-8') as f:
        f.write('return ')
        f.write(luastr)
      print('save %s from %s in %s' % (record.exportfile, record.sheet.name, record.path))
      
    elif self.context.format == 'ycl':
      g = toycl(record.obj)
      next(g) # skip first newline
      yclstr = "".join(g)
      with codecs.open(record.exportfile, 'w', 'utf-8') as f:
        f.write(yclstr)
      print('save %s from %s in %s' % (record.exportfile, record.sheet.name, record.path))
  
  def checksheetname(self, path, sheetname, root):
    r = next((r for r in self.records if r.root == root), False)
    if r:
      raise ValueError('%s in %s is already defined in %s' % (root, path, r.path))
     
def export(context, path):
  try:
    return Exporter(context).export(path)
  except Exception as e:  
    return traceback.format_exc()

def exportpack(args):
  return export(args[0], args[1])

def exportfiles(context):
  paths = []
  for path in re.split(r'[,;|]+', context.path.strip()):
    if path:
      if not os.path.isfile(path):
        raise ValueError('%s is not exists' % path)
      elif path in paths:
        raise ValueError('%s is already has' % path)    
      paths.append(path)

  errors = []
  schemas = []

  def append(result):
    if type(result) is str:
      errors.append(result)
    else:   
      schemas.extend(result)
      
  if context.multiprocessescount is None or context.multiprocessescount > 1:
    with multiprocessing.Pool(context.multiprocessescount) as p:
      for i in p.map(exportpack, [(context, x) for x in paths]):
        append(i)
  else:
    for path in paths:
      result = export(context, path)
      append(result)

  if schemas:
    if context.codegenerator:
      schemasjson = json.dumps(schemas, ensure_ascii = False, indent = 2)
      dir = os.path.dirname(context.codegenerator)
      if dir and not os.path.isdir(dir):
        os.makedirs(dir)
      with codecs.open(context.codegenerator, 'w', 'utf-8') as f:
        f.write(schemasjson)

    exports = []
    for schema in schemas:
      exportfile = schema['exportfile']
      r = next((r for r in exports if r['exportfile'] == exportfile), False)
      if r:
        errors.append('%s in %s is already defined in %s' % (schema['root'], schema['path'], r['path']))
        os.remove(exportfile)
      else:
        exports.append(schema)

  if errors:
    print('\n\n'.join(errors))
    sys.exit(-1)

  print("export finsish successful!!!")

class Context:
  '''usage python proton.py [-p filelist] [-f outfolder] [-e format]
  Arguments
  -p      : input excel files, use , or ; or space to separate
  -f      : out folder
  -e      : format, json or xml or lua or ycl

  Options
  -s      ：sign, controls whether the column is exported, defalut all export
  -t      : suffix, export file suffix
  -r      : the separator of object field, default is ; you can use it to change
  -m      : use the count of multiprocesses to export, default is cpu count
  -c      : a file path, save the excel structure to json
            the external program uses this file to automatically generate the read code
  -h      : print this help message and exit

  https://github.com/yanghuan/proton'''

if __name__ == '__main__':
  print('argv:' , sys.argv)
  opst, args = getopt.getopt(sys.argv[1:], 'p:f:e:s:t:r:m:c:h')

  context = Context()
  context.path = None
  context.folder = '.'
  context.format = 'json'
  context.sign = None
  context.extension = None
  context.objseparator = ';'
  context.codegenerator = None
  context.multiprocessescount = None

  for op, v in opst:
    if op == '-p':
      context.path = v
    elif op == '-f':
      context.folder = v
    elif op == '-e':
      context.format = v.lower() 
    elif op == '-s':
      context.sign = v 
    elif op == '-t':
      context.extension = v
    elif op == '-r':
      context.objseparator = v
    elif op == '-m':
      context.multiprocessescount = int(v) if v is not None else None
    elif op == '-c':
      context.codegenerator = v    
    elif op == '-h':
      print(Context.__doc__)
      sys.exit()
      
  if not context.path:
    print(Context.__doc__)
    sys.exit(2)

  exportfiles(context)
