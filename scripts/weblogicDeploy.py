import sys
import getopt
from java.util import Properties
from java.io import FileInputStream
from java.io import File

def usage():
    print "Usage:"
    print "deployWLST.py [-t timeout] [-i interval]"
def connectConsole(weblogicEndpoint, weblogicUser, weblogicPassword):
    connect(weblogicUser, weblogicPassword, weblogicEndpoint)
    print '-'*100+"\n" + "Connected to weblogic: " + weblogicEndpoint + "\n"+'-'*100
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
def deployAplication(appName, clusterName):
    print '-'*100+"\n" + "Starting deploy of " + appName + "\n"+'-'*100
    deploy(appName, artifact, targets=clusterName, upload='true')
    startApplication(appName)
    print '-'*100+"\n" + "Deploy sucess" + "\n"+'-'*100

#====== Main program ===============================
try:
    opts, args = getopt.getopt( sys.argv[1:], "e:u:p:n:a:c:", ["weblogicEndpoint","weblogicUser","weblogicPassword","appName","artifact","clusterName"] )
except getopt.GetoptError, err:
    print str(err)
    usage()
    sys.exit(2)

#===== Handling get options  ===============
for opt, arg in opts:
    if opt == "-e":
        weblogicEndpoint = arg
    elif opt == "-u":
        weblogicUser = arg
    elif opt == "-p":
        weblogicPassword = arg
    elif opt == "-n":
        appName = arg
    elif opt == "-a":
        artifact = arg
    elif opt == "-c":
        clusterName = arg

connectConsole(weblogicEndpoint, weblogicUser, weblogicPassword)
removeAplication(appName)
deployAplication(appName,clusterName)
