import sys
import getopt
from java.util import Properties
from java.io import FileInputStream
from java.io import File

def usage():
    print "Usage:"
    print "deployWLST.py [-t timeout] [-i interval]"
def connectConsole(weblogicPassword,weblogicURL):
    connect('weblogic', weblogicPassword, weblogicURL)
    print '-'*100+"\n" + "Connected to weblogic: " + weblogicURL + "\n"+'-'*100
def removeAplication(appName):
    deployed_application_names = [];
    app_deployments = cmo.getAppDeployments()

    for app_deployment in app_deployments:
        deployed_application_names.append(app_deployment.getName())

    if appName in str(deployed_application_names):
        print '-'*100+"\n" + appName + ": Exists: stop and undeploy" + "\n"+'-'*100
        stopApplication(appName)
        undeploy(appName)
        print '-'*100+"\n" + "Aplication stop and undeploy sucess" + "\n"+'-'*100
    else:
        print '-'*100+"\n" + appName + ": Doesnt exist" + "\n"+'-'*100
def deployAplication(appName):
    print '-'*100+"\n" + "Starting deploy of " + appName + "\n"+'-'*100
    deploy(appName, artifact, targets='cl_integracao', upload='true')
    startApplication(appName)
    print '-'*100+"\n" + "Deploy sucess" + "\n"+'-'*100

#====== Main program ===============================
try:
    opts, args = getopt.getopt( sys.argv[0:], "u:p:n:a:b", ["weblogicURL","weblogicPassword","appName","artifact","batata"] )
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

#===== Handling get options  ===============
for opt, arg in opts:
    if opt == "-u":
        weblogicURL = arg
    elif opt == "-p":
        weblogicPassword = arg
    elif opt == "-n":
        appName = arg
    elif opt == "-a":
        artifact = arg
    elif opt == "-b":
        batata = arg


print "weblogicURL: " + weblogicURL
print "weblogicPassword: " + weblogicPassword
print "appName: " + appName
print "artifact: " + artifact
print "batata: " + batata

#connectConsole(weblogicPassword,weblogicURL)
#removeAplication(appName)
#deployAplication(appName)
