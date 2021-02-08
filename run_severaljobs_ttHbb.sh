#!/usr/bin/env sh

##### Parameters to modify
SAMPLE="ttHbbSL"            #### can be or ttHbb or ttbar
TOTALNEVENTS=10000       #### total number of events
NJOBS=2                  #### number of jobs submitted in parallel
FIRSTJOB=9              #### this is just a label, your jobs will be named ttbar_FIRSTJOB
CMSDIR="/afs/cern.ch/user/c/chreisse/Delphes/CMSSW_9_1_0_pre3/src/"  #### change with your CMSSW release directory
WORKINGDIR="/afs/cern.ch/user/c/chreisse/Delphes/delphes/examples/DelphesSimulation/"${SAMPLE}"/" #### change with your Delphes directory
#LOGDIR="/afs/cern.ch/work/c/chreisse/DelphesSimulation/Logs/"${SAMPLE}"/" #### change with your Delphes directory
#OUTDIR="/afs/cern.ch/work/c/chreisse/DelphesSimulation/"${SAMPLE}"/" #### change with your output directory
USERPROXY=/afs/cern.ch/user/c/chreisse/mycert   #### change with your proxy name


#### script
if [ ! -d ${WORKINGDIR} ]; then
  echo "Creating working directory"
  mkdir ${WORKINGDIR}
fi
if [ ! -d ${OUTDIR} ]; then
  echo "Creating output directory"
  mkdir ${OUTDIR}
fi
if [ ! -d ${LOGDIR} ]; then
  echo "Creating log directory"
  mkdir ${LOGDIR}
fi
OUTPUTFile='delphesSample_'${SAMPLE}
if [[ ${SAMPLE} = "ttHbb" ]]; then
    TARBALL="/cvmfs/cms.cern.ch/phys_generator/gridpacks/2017/13TeV/powheg/V2/ttH_inclusive_hdamp_NNPDF31_13TeV_M125/v1/ttH_inclusive_hdamp_NNPDF31_13TeV_M125.tgz"
fi
if [[ ${SAMPLE} = "ttHbbSL" ]]; then
    TARBALL="/cvmfs/cms.cern.ch/phys_generator/gridpacks/2017/13TeV/powheg/V2/ttH_ttToSemiLep_hdamp_NNPDF31_13TeV_M125/ttH_slc6_amd64_gcc630_CMSSW_9_3_0_ttH_ttToSemiLep_hdamp_NNPDF31_13TeV_M125.tgz"
fi
if [[ ${SAMPLE} = "TTbar" ]]; then
    TARBALL="/cvmfs/cms.cern.ch/phys_generator/gridpacks/2017/13TeV/powheg/V2/TT_hvq/TT_hdamp_NNPDF31_NNLO_ljets.tgz"
fi
NEVENTS=$((${TOTALNEVENTS}/${NJOBS}))
for (( i = ${FIRSTJOB}; i < ${NJOBS}+${FIRSTJOB}; i++ )); do

  echo "Creating job "${i}
  ##### Creating folders
  NEWDIR=${WORKINGDIR}/${SAMPLE}_${i}
  if [ -d ${NEWDIR} ]; then
    rm -r ${NEWDIR}
  fi
  mkdir -p ${NEWDIR}
  cd ${NEWDIR}

  FILETOSUBMIT="run_job_${SAMPLE}_${i}.sh"
  ##### Creating file to submit jobs
  echo """#!/usr/bin/env sh
export X509_USER_PROXY=${USERPROXY}

source /cvmfs/cms.cern.ch/cmsset_default.sh
export SCRAM_ARCH=slc6_amd64_gcc630
cd ${CMSDIR}
eval \`scram runtime -sh\`
cd ${NEWDIR}

##### Running gridpacks
$CMSDIR/GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh ${TARBALL} ${NEVENTS} ${RANDOM} 10
mv cmsgrid_final.lhe cmsgrid_final_${i}.lhe

##### RUnning delphes with Pythia8
cd ${CMSDIR}
eval \`scram runtime -sh\`
cd ${NEWDIR}
export PYTHIA8=/cvmfs/cms.cern.ch/slc6_amd64_gcc530/external/pythia8/223-mlhled2/
export LD_LIBRARY_PATH=\$PYTHIA8/lib:\$LD_LIBRARY_PATH

cp ${WORKINGDIR}/../configLHE_${SAMPLE}.cmnd ${NEWDIR}/configLHE_${i}.cmnd
sed -i 's/Main:numberOfEvents = 100/Main:numberOfEvents = ${NEVENTS}/' configLHE_${i}.cmnd
sed -i 's|cmsgrid_final.lhe|'${NEWDIR}'\/cmsgrid_final_'${i}'.lhe|' configLHE_${i}.cmnd

rm ${OUTPUTFile}_${i}.root
${WORKINGDIR}../../../DelphesPythia8 ${WORKINGDIR}../../../cards/CMS_PhaseII/CMS_PhaseII_Substructure_200PU_withHTT_NoEnergyScale.tcl configLHE_${i}.cmnd ${OUTDIR}${OUTPUTFile}_${i}.root

""" >> ${FILETOSUBMIT}
  chmod +x ${FILETOSUBMIT}

  CONDOR_SUBMISSION_SCRIPT="${SAMPLE}_${i}.sub"
  ### Creating file for condor submission
  echo """universe              = vanilla
executable            = ${NEWDIR}/${FILETOSUBMIT}
output                = ${NEWDIR}/run_job_${SAMPLE}_${i}.std
error                 = ${NEWDIR}/run_job_${SAMPLE}_${i}.err
log                   = ${NEWDIR}/run_job_${SAMPLE}_${i}.log
+JobFlavour	      = \"tomorrow\"
queue""" >> ${CONDOR_SUBMISSION_SCRIPT}

  echo "submitting job"
  condor_submit ${CONDOR_SUBMISSION_SCRIPT}

done

cd ${WORKINGDIR}../
echo "Have a nice day :)"
