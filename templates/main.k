import apps
import file
import yaml

_out = [file.write("./apps/${k}.yaml", yaml.encode(v)) for k, v in apps.apps]
