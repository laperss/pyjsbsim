from libcpp cimport bool
from libcpp.string cimport string
from libcpp.vector cimport vector
from string import rfind

import os, platform

cdef extern from "JSBSim/models/FGPropulsion.h" namespace "JSBSim":
    cdef cppclass c_FGPropulsion "JSBSim::FGPropulsion":
        c_FGPropulsion(c_FGFDMExec* fdm)
        void InitRunning(int n)
        int GetNumEngines()

cdef extern from "JSBSim/FGFDMExec.h" namespace "JSBSim":
    cdef cppclass c_FGFDMExec "JSBSim::FGFDMExec":
        c_FGFDMExec(int root, int fdmctr)
        void Unbind()
        bool Run()
        bool RunIC()
        bool LoadModel(string model,
                       bool add_model_to_path)
        bool LoadModel(string aircraft_path,
                       string engine_path,
                       string systems_path,
                       string model,
                       bool add_model_to_path)
        bool LoadScript(string script, double delta_t, string initfile)
        bool SetEnginePath(string path)
        bool SetAircraftPath(string path)
        bool SetSystemsPath(string path)
        void SetRootDir(string path) 
        string GetEnginePath()
        string GetAircraftPath()
        string GetSystemsPath()
        string GetRootDir()
        string GetFullAircraftPath()
        double GetPropertyValue(string property)
        void SetPropertyValue(string property, double value)
        string GetModelName()
        bool SetOutputDirectives(string fname)
        #void ForceOutput(int idx=0)
        void SetLoggingRate(double rate)
        bool SetOutputFileName(string fname)
        #string GetOutputFileName()
        string GetOutputFileName(int n)
        void DoTrim(int mode) except +
        void DoSimplexTrim(int mode) except +
        void DoLinearization(int mode)
        void DisableOutput()
        void EnableOutput()
        void Hold()
        void EnableIncrementThenHold(int time_steps)
        void CheckIncrementalHold()
        void Resume()
        bool Holding()
        #void ResetToInitialConditions()
        void ResetToInitialConditions(int n)
        void SetDebugLevel(int level)
        string QueryPropertyCatalog(string check)
        void PrintPropertyCatalog()
        void SetTrimStatus(bool status)
        bool GetTrimStatus()
        string GetPropulsionTankReport()
        double GetSimTime() 
        double GetDeltaT()
        void SuspendIntegration()
        void ResumeIntegration()
        bool IntegrationSuspended()
        bool Setsim_time(double cur_time)
        void Setdt(double delta_t)
        double IncrTime() 
        int GetDebugLevel()   
        c_FGPropulsion* GetPropulsion()

# this is the python wrapper class
cdef class FGFDMExec:

    cdef c_FGFDMExec *thisptr      # hold a C++ instance which we're wrapping

    def __cinit__(self, **kwargs):
        # this hides startup message
        os.environ["JSBSIM_DEBUG"]=str(0)
        self.thisptr = new c_FGFDMExec(0,0)

    def __init__(self, root_dir=None):
        if root_dir is None:
            self.find_root_dir()
        else:
            if not os.path.isdir(root_dir):
                raise IOError("Can't find root directory: {0}".format(root_dir))

    def simulate(self, record_properties=[], t_final=1, dt=1.0/120, verbose=False):
        y = {}
        t = []
        self.set_dt(dt)
        self.run_ic()
        for prop in record_properties:
            y[prop] = []
        while self.get_sim_time() < t_final:
            if (self.run() == False):
                break
            if verbose:
                print 't:', self.get_sim_time()
            t.append(self.get_sim_time())
            print 'dt: ', self.get_delta_t()
            for prop in record_properties:
                y[prop].append(self.get_property_value(prop))
        return (t,y)

    def find_root_dir(self, search_paths=[], verbose=False):
        root_dir = None
        search_paths.append(os.environ.get("JSBSIM"))
        if platform.system() == "Linux":
            search_paths.append("/usr/local/share/JSBSim/")
            search_paths.append("/usr/local/include/JSBSim/")
            search_paths.append("/usr/share/JSBSim/")
        elif platform.system() == "Windows":
            #TODO add some windows search paths
            pass
        elif platform.system() == "Darwin":
            search_paths.append("/opt/local/share/JSBSim/")
            search_paths.append("/usr/local/share/JSBSim/")

        if verbose:
            print "search_paths"
        for path in search_paths:
            if verbose:
                print '\t', path
            if path is not  None and os.path.isdir(path):
                root_dir = path
                break
        if root_dir is None:
            raise IOError("Could not find JSBSim root, try "
                          "defining JSBSIM environment variable")
        self.set_root_dir(root_dir)

    def __dealloc__(self):
        del self.thisptr

    def __repr__(self):
        return "FGFDMExec \n" \
            "root dir\t:\t{0}\n" \
            "aircraft path\t:\t{1}\n" \
            "engine path\t:\t{2}\n" \
            "systems path\t:\t{3}\n" \
                .format(
                self.get_root_dir(),
                self.get_aircraft_path(),
                self.get_engine_path(),
                self.get_systems_path())

    def run(self):
        """
        This function executes each scheduled model in succession.
        @param return true if successful, false if sim should be ended
        """
        return self.thisptr.Run()

    def run_ic(self):
        """
        Initializes the sim from the initial condition object and executes
        each scheduled model without integrating i.e. dt=0.
        @param return true if successful
        """
        return  self.thisptr.RunIC()

    def load_model(self, model, add_model_to_path = True):
        """
        Loads an aircraft model.
        @param AircraftPath path to the aircraft/ directory. For instance:
            "aircraft". Under aircraft, then, would be directories for various
            modeled aircraft such as C172/, x15/, etc.
        @param EnginePath path to the directory under which engine config
            files are kept, for instance "engine"
        @param SystemsPath path to the directory under which systems config
            files are kept, for instance "systems"
        @param model the name of the aircraft model itself. This file will
            be looked for in the directory specified in the AircraftPath variable,
            and in turn under the directory with the same name as the model. For
            instance: "aircraft/x15/x15.xml"
        @param addModelToPath set to true to add the model name to the
            AircraftPath, defaults to true
        @return true if successful 
        """
        return self.thisptr.LoadModel(model, add_model_to_path)

    def load_model_with_paths(self, model, aircraft_path,
                   engine_path, systems_path, add_model_to_path = True):
        """
        Loads an aircraft model.  The paths to the aircraft and engine
        config file directories must be set prior to calling this.  See
        below.
        @param model the name of the aircraft model itself. This file will
            be looked for in the directory specified in the AircraftPath variable,
            and in turn under the directory with the same name as the model. For
            instance: "aircraft/x15/x15.xml"
        @param addModelToPath set to true to add the model name to the
            AircraftPath, defaults to true
        @return true if successful
        """
        return self.thisptr.LoadModel(model, aircraft_path,
            engine_path, systems_path, add_model_to_path)

    def load_script(self, script, delta_t=0.0, initfile=""):
        """
        Loads a script
        @param Script The full path name and file name for the script to be loaded.
        @param deltaT The simulation integration step size, if given.  If no value is supplied
            then 0.0 is used and the value is expected to be supplied in
            the script file itself.
        @param initfile The initialization file that will override the initialization file
            specified in the script file. If no file name is given on the command line,
            the file specified in the script will be used. If an initialization file 
            is not given in either place, an error will result.
        @return true if successfully loads; false otherwise. */
        """
        return self.thisptr.LoadScript(script, delta_t, initfile)

    def set_engine_path(self, path):
        """
        Sets the path to the engine config file directories.
        @param path path to the directory under which engine config
            files are kept, for instance "engine"
        """
        return self.thisptr.SetEnginePath(path)

    def set_aircraft_path(self, path):
        """
        Sets the path to the aircraft config file directories.
        @param path path to the aircraft directory. For instance:
            "aircraft". Under aircraft, then, would be directories for various
            modeled aircraft such as C172/, x15/, etc. 
        """
        return self.thisptr.SetAircraftPath(path)

    def set_systems_path(self, path):
        """
        Sets the path to the systems config file directories.
        @param path path to the directory under which systems config
            files are kept, for instance "systems"
        """
        return self.thisptr.SetSystemsPath(path)

    def set_root_dir(self, path):
        """
        Sets the root directory where JSBSim starts looking for its system directories.
        @param path the string containing the root directory.
        """
        self.thisptr.SetRootDir(path)

        # this is a hack to fix a bug in JSBSim
        self.set_engine_path("engine")
        self.set_aircraft_path("aircraft")
        self.set_systems_path("systems")

    def get_engine_path(self):
        """
        Retrieves the engine path
        """
        return self.thisptr.GetEnginePath()

    def get_aircraft_path(self):
        """
        Retrieves the aircraft path
        """
        return self.thisptr.GetAircraftPath()

    def get_systems_path(self):
        """
        Retrieves the systems path
        """
        return self.thisptr.GetSystemsPath()

    def get_full_aircraft_path(self):
        """
        Retrieves the full aircraft path name
        """
        return self.thisptr.GetFullAircraftPath()

    def get_root_dir(self):
        """
        Retrieves the Root Directory.
        @return the string representing the root (base) JSBSim directory.
        """
        return self.thisptr.GetRootDir()

    def get_property_value(self, name):
        """
        Retrieves the value of a property.
        @param property the name of the property
        @result the value of the specified property 
        """
        return self.thisptr.GetPropertyValue(name)

    def set_property_value(self, name, value):
        """
        Sets a property value.
        @param property the property to be set
        @param value the value to set the property to *
        """
        self.thisptr.SetPropertyValue(name, value)

    def get_model_name(self):
        """
        Retrieves the model name.
        """
        return self.thisptr.GetModelName()

    def set_output_directive(self, fname):
        """
        Sets the output (logging) mechanism for this run.
        Calling this function passes the name of an output directives file to
        the FGOutput object associated with this run. The call to this function
        should be made prior to loading an aircraft model. This call results in an
        FGOutput object being built as the first Output object in the FDMExec-managed
        list of Output objects that may be created for an aircraft model. If this call
        is made after an aircraft model is loaded, there is no effect. Any Output
        objects added by the aircraft model itself (in an &lt;output> element) will be
        added after this one. Care should be taken not to refer to the same file
        name.
        An output directives file contains an &lt;output> &lt;/output> element, within
        which should be specified the parameters or parameter groups that should
        be logged.
        @param fname the filename of an output directives file.
        """
        return self.thisptr.SetOutputDirectives(fname)

    #def force_output(self, index):
        #"""
        #Forces the specified output object to print its items once
        #"""
        #self.thisptr.ForceOutput(index)

    def set_logging_rate(self, rate):
        """
        Sets the logging rate for all output objects (if any).
        """
        self.thisptr.SetLoggingRate(rate)

    def get_output_filename(self):
        """
        Retrieves the current output filename.
        @return the name of the output file for the first output specified by the flight model.
            If none is specified, the empty string is returned.
        """
        return self.thisptr.GetOutputFileName(0)

    def do_trim(self, mode):
        """
        Executes trimming in the selected mode.
        @param mode Specifies how to trim:
            - tLongitudinal=0
            - tFull
            - tGround
            - tPullup
            - tCustom
            - tTurn
            - tNone
        """
        self.thisptr.DoTrim(mode)

    def do_simplex_trim(self, mode):
        """
        Executes simplex trimming in the selected mode.
        @param mode Specifies how to trim:
            - tLongitudinal=0
            - tFull
            - tGround
            - tPullup
            - tCustom
            - tTurn
            - tNone
        """
        self.thisptr.DoSimplexTrim(mode)

    def do_linearization(self):
        """
        Executes linearization with state-space output
            * You must trim first to get an accurate state-space model
        """
        self.thisptr.DoLinearization(0)

    def do_disable_output(self):
        """
        Disables data logging to all outputs.
        """
        self.thisptr.DisableOutput()

    def do_enable_output(self):
        """
        Enables data logging to all outputs.
        """
        self.thisptr.EnableOutput()

    def hold(self):
        """
        Pauses execution by preventing time from incrementing.
        """
        self.thisptr.Hold()

    def enable_increment_then_hold(self, time_steps):
        """
        Turn on hold after increment
        """
        self.thisptr.EnableIncrementThenHold(time_steps)

    def check_incremental_hold(self):
        """
        Checks if required to hold afer increment
        """
        self.thisptr.CheckIncrementalHold()

    def resume(self):
        """
        Resumes execution from a "Hold".
        """
        self.thisptr.Resume()

    def holding(self):
        """
        Returns true if the simulation is Holding (i.e. simulation time is not moving).
        """
        return self.thisptr.Holding()

    def reset_to_initial_conditions(self):
        """
        Resets the initial conditions object and prepares the simulation to run again.
        """
        self.thisptr.ResetToInitialConditions(0)

    def set_debug_level(self, level):
        """
        Sets the debug level.
        """
        self.thisptr.SetDebugLevel(level) 

    def query_property_catalog(self, check):
        """
        Retrieves property or properties matching the supplied string.
        A string is returned that contains a carriage return delimited list of all
        strings in the property catalog that matches the supplied check string.
        @param check The string to search for in the property catalog.
        @return the carriage-return-delimited string containing all matching strings
            in the catalog.
        """
        return (self.thisptr.QueryPropertyCatalog(check)).rstrip().split('\n')

    def get_property_catalog(self, check):
        """
        Retrieves the property catalog as a dictionary.
        """
        catalog = {}
        for item in self.query_property_catalog(check):
            if(item.count(' ') == 0):
                catalog[item] = self.get_property_value(item)
            else:
                name = item[0:rfind(item," ")]
                catalog[name] = self.get_property_value(name)                
        return catalog

    def print_property_catalog(self):
        """
        Print the contents of the property catalog for the loaded aircraft.
        """
        self.thisptr.PrintPropertyCatalog()

    def set_trim_status(self, status):
        self.thisptr.SetTrimStatus(status)

    def get_trim_status(self):
        return self.thisptr.GetTrimStatus()

    def get_propulsion_tank_report(self):
        return self.thisptr.GetPropulsionTankReport()

    def get_sim_time(self):
        """
        Returns the cumulative simulation time in seconds.
        """
        return self.thisptr.GetSimTime()

    def get_delta_t(self):
        """
        Returns the simulation delta T.
        """
        return self.thisptr.GetDeltaT()

    def suspend_integration(self):
        """
        Suspends the simulation and sets the delta T to zero.
        """
        self.thisptr.SuspendIntegration()

    def resume_integration(self):
        """
        Resumes the simulation by resetting delta T to the correct value.
        """
        self.thisptr.ResumeIntegration()

    def integration_suspended(self):
        """
        Returns the simulation suspension state.
        @return true if suspended, false if executing
        """
        return self.thisptr.IntegrationSuspended()

    def set_sim_time(self, time):
        """
        Sets the current sim time.
        @param time the current time
        @return the current simulation time.
        """
        return self.thisptr.Setsim_time(time)

    def set_dt(self, dt):
        """
        Sets the integration time step for the simulation executive.
        @param dt the time step in seconds.
        """
        self.thisptr.Setdt(dt)

    def incr_time(self): 
        """
        Increments the simulation time if not in Holding mode. The Frame counter
        is also incremented.
        @return the new simulation time.
        """
        return self.thisptr.IncrTime()

    def get_debug_level(self):
        """
        Retrieves the current debug level setting.
        """
        return self.thisptr.GetDebugLevel()

    def propulsion_init_running(self, n):
        self.thisptr.GetPropulsion().InitRunning(n)

    def propulsion_get_num_engines(self):
        return self.thisptr.GetPropulsion().GetNumEngines()
