the **Revealer Toolkit** is a framework and simple scripts for computer forensics. It uses Brian Carrier's The Sleuth Kit as the backbone, as well as other free tools.

The aim of the Revealer Toolkit is to automate rutinary tasks and to manage sources and results from another perspective than the usual forensic frameworks. It will be specially useful in cases with several computers and digitals forensic sources.

RVT is developed and actively tested by computer forensic investigators working at [EVIDENTIA](http://www.evidentia.biz)  and [INCIDE](http://www.incide.es), spanish companies sited at the beautiful city of Barcelona

You can find additional information, packages and all the source code at http://code.google.com/p/revealertoolkit


## Introduction to version 0.2.1 ##

The current state of the project can be described as a _proof of concept_, that is, RVT version 0.2 proofs that the objectives we are looking for are reachable, but further work is necessary in order to have a stable version.

Therefore, RVT v0.2 can be used to automate computer forensic tasks on a group of several digital forensic images, but the code is still buggy, some tasks have to be run manually, and the interface has to be improved. RVT code and documentation can be downloaded from:

  * http://revealertoolkit.googlecode.com/files/RVT_v0.2.1.zip
  * svn checkout http://revealertoolkit.googlecode.com/svn/tags/RVT-v0.2.1 RVT-v0.2.1-read-only

Also, a virtual machine (VMWare) with a functional RVT v0.2 system is available at Sourceforge at this [link](https://sourceforge.net/projects/revealertoolkit/files/revealertoolkit/v0.2/RVT-v0.2.tar.gz/download) .

The objective of next version (0.3) will be to clean the code, solve bugs and ease the interaction. At the same time, more scripts and modules will be developed. For version 0.3, a _RVT Developer Manual_ is planned, as well as a automated reporting engine.

For any questions, help or comments, please, do not hesitate to drop an message in our newsletter (http://groups.google.com/group/revealertoolkit).

## Acknowledgements ##

  * Manu Ginés aka xkulio, creator of the original Chanchullos Revealer
  * People that have collaborated to (and suffered) the project:  Jose Navarro, Luis Gómez, Sara Rincón, Abraham Pasamar, Julián Sotos, Helena Fuentes, Emili García, Harlan Carvey, ...
  * We want to specially thank Harlan Carvey, author of the well-known [Windows Incident Response blog](http://windowsir.blogspot.com), for kindly providing us with brilliant Perl code to parse Windows event files (EVT extension):   [evtparse.pl](http://code.google.com/p/revealertoolkit/source/browse/trunk/tools/evtparse.pl) and [evtrpt.pl](http://code.google.com/p/revealertoolkit/source/browse/trunk/tools/evtrpt.pl)
  * We want to specially thank Jacob Cunningham for his Perl script to parse LNK files