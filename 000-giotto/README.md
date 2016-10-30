<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/Magopancione/AzureP/master/azuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/Magopancione/AzureP/master/azuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template lets you create a 9 node on Azure.  It's tested on Ubuntu 14.04 LTS  

Download Evinronment Deploy script
 
To run this script: 
 
Login-AzureRmAccount

.\Deploy-AzureResourceGroup.ps1 -ResourceGroupLocation 'eastus' -ArtifactStagingDirectory 'ClusteringGiotto'