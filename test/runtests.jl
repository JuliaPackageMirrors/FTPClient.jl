push!(LOAD_PATH, "./src")

using FTPClient
using FactCheck
if VERSION >= v"0.5-"
    using Base.Test
else
    using BaseTestNext
    const Test = BaseTestNext
    typealias Future RemoteRef
end
using JavaCall
using Compat
using LibCURL

function start_server()
    port = jcall(MockFTPServerJulia, "setUp", jint, ())
    @assert port > 0 "start_server failed"
    port
end

function stop_server()
    result = jcall(MockFTPServerJulia, "tearDown", jboolean, ())
    @assert result == 1 "stop_server failed"
end

function set_user(name::AbstractString, password::AbstractString, home_dir::AbstractString)
    result = jcall(MockFTPServerJulia, "setUser", jboolean, (JString, JString, JString), name, password, home_dir)
    @assert result == 1 "set_user failed"
end

function set_file(name::AbstractString, content::AbstractString)
    result = jcall(MockFTPServerJulia, "setFile", jboolean, (JString, JString), name, content)
    @assert result == 1 "set_file failed"
end

function set_byte_file(name::AbstractString, content::AbstractString)
    result = jcall(MockFTPServerJulia, "setByteFile", jboolean, (JString, JString), name, content)
    @assert result == 1 "set_byte_file failed"
end

function set_command_response(request::AbstractString, code::Integer, reponse::AbstractString)
    result = jcall(MockFTPServerJulia, "setCommandResponse", jboolean, (JString, jint, JString,), request, code, reponse)
    @assert result == 1 "set_command_response failed"
end

function set_errors()
    result = jcall(MockFTPServerJulia, "setErrors", jboolean, ())
    @assert result == 1 "set_errors failed"
end

function set_list_error()
    result = jcall(MockFTPServerJulia, "setListError", jboolean, ())
    @assert result == 1 "set_list_error failed"
end

function set_type_error()
    result = jcall(MockFTPServerJulia, "setTypeError", jboolean, ())
    @assert result == 1 "set_type_error failed"
end

function undo_errors()
    result = jcall(MockFTPServerJulia, "undoErrors", jboolean, ())
    @assert result == 1 "undo_errors failed"
end

new_file = "new_name.txt"
testdir = "testdir"
host = "localhost"
original_host = host
user = "test"
pswd = "test"
home_dir = "/"
file_name = "test_download.txt"
file_name2 = "test_download2.txt"
directory_name = "test_directory"
file_size = rand(1:100)
file_contents = randstring(file_size)
@unix_only byte_file_contents = string("466F6F426172", "0D0A", "466F6F426172")
@windows_only byte_file_contents = string("466F6F426172", "0A", "466F6F426172", "1A1A1A")
byte_file_name = randstring(20)
upload_file = "test_upload.txt"
f =  open(upload_file, "w")
write(f, "Test file to upload.\n")
close(f)


if (length(ARGS) >= 1 && ARGS[1] == "true")
    test_ssl = true
else
    test_ssl = false
end

if (length(ARGS) >= 2 && ARGS[2] == "true")
    test_implicit = true
else
    test_implicit = false
end

if (length(ARGS) == 4)
    user = ARGS[3]
    pswd = ARGS[4]
end

if (test_ssl)
    if (test_implicit)
        fp = joinpath(dirname(@__FILE__), "test_implicit_ssl.jl")
        println("$fp ...\n")
        include(fp)
    else
        fp = joinpath(dirname(@__FILE__), "test_explicit_ssl.jl")
        println("$fp ...\n")
        include(fp)
    end
else
    # Start Java, and point to the class in this directory
    pkg_dir = joinpath(dirname(@__FILE__), "..")
    JavaCall.init([
        "-Djava.class.path=$(joinpath(pkg_dir, "test"))",
        "-Djava.ext.dirs=$(joinpath(pkg_dir, "deps", "ext"))",
    ])
    MockFTPServerJulia = @jimport MockFTPServerJulia

    set_user(user, pswd, home_dir)
    set_file("/" * file_name, file_contents)
    set_file("/" * directory_name * "/" * file_name2, file_contents)
    set_byte_file("/" * byte_file_name, byte_file_contents)
    set_command_response("AUTH", 230, "Login successful.")
    port = start_server()
    host = "$original_host:$port"

    # Note: If LibCURL complains that the server doesn't listen it probably means that
    # the MockFtpServer isn't ready to accept connections yet.

    test_files = ["test_non_ssl.jl", "test_ftp_object.jl"]

    for file in test_files
        fp = joinpath(dirname(@__FILE__), file)
        println("$fp ...\n")
        include(fp)
    end

    # Basic commands will now error
    set_errors()

    test_file = "test_client_errors.jl"
    fp = joinpath(dirname(@__FILE__), test_file)
    println("$fp ...\n")
    include(fp)

    stop_server()
    JavaCall.destroy()

end

# Done testing
rm(upload_file)

# Throws errors when a @fact failed a test.
exitstatus()
