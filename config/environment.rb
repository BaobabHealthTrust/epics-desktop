# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
EpicsBdeTool::Application.initialize!

bart = (YAML.load_file("config/database.yml")['openmrs'] )
User.establish_connection(bart)
OpenmrsPerson.establish_connection(bart)
OpenmrsPersonName.establish_connection(bart)
