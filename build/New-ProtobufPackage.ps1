param(
    $Version = "main"
)

New-Variable -Name "PROTO_REPO" -Value "https://github.com/THD-C/Protocol.git" -Option ReadOnly -Scope Script -Force
New-Variable -Name "PROTO_REPO_PATH" -Value "./proto" -Option ReadOnly -Scope Script -Force
New-Variable -Name "PROTO_PATH" -Value "./Protocol/proto" -Option ReadOnly -Scope Script -Force
New-Variable -Name "ROOT_PACKAGE_DIR" -Value "./thdcgrpc" -Option ReadOnly -Scope Script -Force

function Invoke-Main {
    Set-PythonEnv
    $packages = Invoke-ProtobufCompiler

    Write-Host "`nProtobuf package has been generated. Version: $Version"
    Write-Host "Packages:"
    $packages | ForEach-Object {
        Write-Host $_
    }
}
function Set-PythonEnv {
    pip install -r ./build/requirements.txt
}
function Invoke-ProtobufCompiler {
    $ProtoFiles = (Get-ChildItem -Path $PROTO_REPO_PATH -Filter *.proto -Recurse)
    $ProtoDirs = @()
    foreach ($file in $ProtoFiles) {
        $ProtoFilePath = (Resolve-Path -Path $file.FullName -Relative -RelativeBasePath $PROTO_REPO_PATH).Replace("./", "")
        $ProtoDirs += $(Split-Path -Path $ProtoFilePath -Parent)
        Write-Host "python -m grpc_tools.protoc --proto_path=$PROTO_REPO_PATH --python_out=. --grpc_python_out=. --pyi_out=. `"$ProtoFilePath`""
        python -m grpc_tools.protoc --proto_path="$PROTO_REPO_PATH" --python_out=. --grpc_python_out=. --pyi_out=. "$ProtoFilePath"
    }

    $ProtoDirs = $($ProtoDirs | Sort-Object -Unique)
    if (Test-Path -Path $ROOT_PACKAGE_DIR) {
        Remove-Item -Path $ROOT_PACKAGE_DIR -Recurse -Force
    }
    $null = New-Item -Path $ROOT_PACKAGE_DIR -ItemType Directory

    foreach ($dir in $ProtoDirs) {
        Move-Item -Path "./$dir" -Destination "./$ROOT_PACKAGE_DIR/$dir" -Force
    }
    return $ProtoDirs
}

Invoke-Main