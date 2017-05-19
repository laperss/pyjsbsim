# PyJSBSim
A python interface to JSBSim. This fork of the original project fixes it so that I can run it with the version of JSBSim I have installed on Ubuntu 16.04. 

## Installation:
If your installation of JSBSim does not use the c++-11 standard, then install using:
```bash
export JSBSIM="/usr/local/include/JSBSim/"
sudo CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0" python setup.py install
```

## Dependencies

* Cython
* NumPy
