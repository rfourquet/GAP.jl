## dealing with GAP packages

"""
    LoadPackageAndExposeGlobals(package::String, mod::String; all_globals::Bool = false)
    LoadPackageAndExposeGlobals(package::String, mod::Module = Main; all_globals::Bool = false, overwrite::Bool = false)

`LoadPackageAndExposeGlobals` loads `package` into GAP via `LoadPackage`,
and stores all newly defined GAP globals as globals in the module `mod`. If `mod` is
a string, the function creates a new module, if `mod` is a Module, it uses `mod` directly.

The function is intended to be used for creating mock modules for GAP packages.
If you load the package `CAP` via

    LoadPackageAndExposeGlobals( "CAP", "CAP" )

you can use CAP commands via

    CAP.PreCompose( a, b )

If `overwrite` is true, Symbols already in the `Main` module will be overloaded.
Be aware that this flag only works in `Main`.

"""
function LoadPackageAndExposeGlobals(
    package::String,
    mod::String;
    all_globals::Bool = false,
)
    mod_sym = Symbol(mod)
    Base.MainInclude.eval(:(module $(mod_sym)
    import GAP
    end))
    ## Adds the new module to the Main module, so it is directly accessible in the julia REPL
    mod_mod = Base.MainInclude.eval(:(Main.$(mod_sym)))

    ## We need to call `invokelatest` as the module `mod_mod` was only created during the
    ## call of this function in a different module, so its world age is higher than the
    ## function calls world age.
    Base.invokelatest(
        LoadPackageAndExposeGlobals,
        package,
        mod_mod;
        all_globals = all_globals,
    )
end

function LoadPackageAndExposeGlobals(
    package::String,
    mod::Module;
    all_globals::Bool = false,
    overwrite::Bool = false,
)
    current_gvar_list = nothing
    if !all_globals
        current_gvar_list = Globals.ShallowCopy(Globals.NamesGVars())
    end
    load_package = evalstr("LoadPackage(\"$package\")")
    if load_package == Globals.fail
        error("cannot load package $package")
    end
    new_gvar_list = Globals.NamesGVars()
    if !all_globals
        new_gvar_list = Globals.Difference(new_gvar_list, current_gvar_list)
    end
    new_symbols = gap_to_julia(Array{Symbol,1}, new_gvar_list)
    for sym in new_symbols
        if overwrite || !isdefined(mod, sym)
            try
                mod.eval(:($(sym) = GAP.Globals.$(sym)))
            catch
            end
        end
    end
end

export LoadPackageAndExposeGlobals


module Packages

import ...GAP: Globals, julia_to_gap, GAPROOT

"""
    load(desc::String, version::String = "")

Try to load the newest installed version of the GAP package with name `desc`.
Return `true` if this is successful, and `false` otherwise.

The function calls [GAP's `LoadPackage` function](GAP_ref(ref:LoadPackage));
the package banner is not printed.
"""
function load(desc::String, version::String = "")
    return Globals.LoadPackage(julia_to_gap(desc),
                               julia_to_gap(version), false) == true
    # TODO: can we provide more information in case of a failure?
    # GAP unfortunately only gives us info messages...
end

"""
    install(desc::String, interactive::Bool = true)

Download and install the newest released version of the GAP package
given by `desc` in the `pkg` subdirectory of GAP's build directory
(variable `GAP.GAPROOT`).
Return `true` if the installation is successful or if the package
was already installed, and `false` otherwise.

`desc` can be either the package name or an URL of an archive or repository
of the package, or an URL of its `PackageInfo.g` file.

The function uses [the function `InstallPackage` from GAP's package
`PackageManager`](GAP_ref(PackageManager:InstallPackage)).
"""
function install(desc::String; interactive::Bool = true, pkgdir::AbstractString = GAPROOT * "/pkg")
    res = load("PackageManager")
    @assert res
    # FIXME: crude hack to allow PackageManager 1.0 shipped with GAP
    # 4.11.0 to work with out of tree builds. For a proper fix, see
    # <https://github.com/gap-packages/PackageManager/pull/55>.
    Globals.PKGMAN_BuildPackagesScript = julia_to_gap(GAPROOT * "/bin/BuildPackages.sh")

    # point PackageManager to our internal pkg dir
    Globals.PKGMAN_CustomPackageDir = julia_to_gap(pkgdir)

    return Globals.InstallPackage(julia_to_gap(desc), interactive)
end

"""
    update(desc::String)

Update the GAP package given by `desc` that is installed in the
`pkg` subdirectory of GAP's build directory (variable `GAP.GAPROOT`),
to the latest version.
Return `true` if a newer version was installed successfully,
or if no newer version is available, and `false` otherwise.

`desc` can be either the package name or an URL of an archive or repository
of the package, or an URL of its `PackageInfo.g` file.

The function uses [the function `UpdatePackage` from GAP's package
`PackageManager`](GAP_ref(PackageManager:UpdatePackage)).
"""
function update(desc::String; interactive::Bool = true, pkgdir::AbstractString = GAPROOT * "/pkg")
    res = load("PackageManager")
    @assert res

    # point PackageManager to our internal pkg dir
    Globals.PKGMAN_CustomPackageDir = julia_to_gap(pkgdir)

    return Globals.UpdatePackage(julia_to_gap(desc), interactive)
end
# note that the updated version cannot be used in the current GAP session,
# because the older version is already loaded;
# thus nec. to start Julia anew

"""
    remove(desc::String)

Remove the GAP package with name `desc` that is installed in the
`pkg` subdirectory of GAP's build directory (variable `GAP.GAPROOT`).
Return `true` if the removal was successful, and `false` otherwise.

The function uses [the function `RemovePackage` from GAP's package
`PackageManager`](GAP_ref(PackageManager:RemovePackage)).
"""
function remove(desc::String; interactive::Bool = true, pkgdir::AbstractString = GAPROOT * "/pkg")
    res = load("PackageManager")
    @assert res

    # point PackageManager to our internal pkg dir
    Globals.PKGMAN_CustomPackageDir = julia_to_gap(pkgdir)

    return Globals.RemovePackage(julia_to_gap(desc), interactive)
end

end