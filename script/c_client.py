import sys
import os
import getopt
import subprocess
import shutil

def main():
    try:
        opts, args = getopt.getopt(
            sys.argv[1:], 
            "c:l:s:p:m", 
            ["server-side", "child-script=", "c-output=", "h-output="]
        )
    except getopt.GetoptError as err:
        print("Error:", err)
        sys.exit(1)

    c_output = None
    h_output = None
    child_script = None

    # Options to forward to c_client.py
    forward_opts = []

    for (opt, arg) in opts:
        if opt == "--child-script":
            child_script = arg
        elif opt == "--c-output":
            c_output = arg
        elif opt == "--h-output":
            h_output = arg
        else:
            if arg:
                forward_opts.extend([opt, arg])
            else:
                forward_opts.append(opt)

    if not c_output:
        print("Error: --c-output must be provided")
        sys.exit(1)

    if not h_output:
        print("Error: --h-output must be provided")
        sys.exit(1)

    if not child_script:
        print("Error: --child-script must be provided (path to c_client.py)")
        sys.exit(1)

    if not args:
        print("Error: Missing XML file argument")
        sys.exit(1)

    xml_file = args[0]

    # Run child c_client.py with forwarded args
    cmd = [sys.executable, child_script] + forward_opts + [xml_file]
    subprocess.check_call(cmd)

    # Determine generated base filename (same as XML without extension)
    base_name = os.path.splitext(os.path.basename(xml_file))[0]
    generated_c = f"{base_name}.c"
    generated_h = f"{base_name}.h"

    # Move files if requested
    shutil.move(generated_c, c_output)
    shutil.move(generated_h, h_output)

if __name__ == "__main__":
    main()
