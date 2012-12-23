 # python with all required eggs
[adhocpy]
recipe = zc.recipe.egg
eggs =  ${buildout:eggs}
interpreter = adhocpy
scripts = adhocpy

# unified directory structure of installed eggs
[omelette]
recipe = collective.recipe.omelette
eggs =
   ${buildout:eggs}
   supervisor

