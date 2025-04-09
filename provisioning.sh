#!/bin/bash

# This file will be sourced in init.sh

# https://raw.githubusercontent.com/ai-dock/comfyui/main/config/provisioning/default.sh

# Packages are installed after nodes so we can fix them...

#DEFAULT_WORKFLOW="https://..."

APT_PACKAGES=(
    "libgl1-mesa-glx"
    "libglib2.0-0"
    "libsm6"
    "libxext6"
    "libxrender-dev"
    "curl"
    "jq"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/logtd/ComfyUI-Fluxtapoz"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/chrisgoringe/cg-use-everywhere"
)

CHECKPOINT_MODELS=(
    
)

UNET_MODELS=(

)

LORA_MODELS=(
    "1595505" # Civitai model ID (just the number)
)

VAE_MODELS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors"
)

ESRGAN_MODELS=(
    
)

CONTROLNET_MODELS=(
    
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/ckpt" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_civitai_models \
        "${WORKSPACE}/storage/stable_diffusion/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
            "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
        else
            micromamba run -n comfyui pip install --no-cache-dir "$@"
        fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_default_workflow() {
    if [[ -n $DEFAULT_WORKFLOW ]]; then
        workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
        if [[ -n $workflow_json ]]; then
            echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
        fi
    fi
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        if [[ -n $url ]]; then
            printf "Downloading: %s\n" "${url}"
            provisioning_download "${url}" "${dir}"
            printf "\n"
        fi
    done
}

function provisioning_get_civitai_models() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) from Civitai to %s...\n" "${#arr[@]}" "$dir"
    for model_id in "${arr[@]}"; do
        if [[ -n $model_id ]]; then
            printf "Processing Civitai model ID: %s\n" "${model_id}"
            download_civitai_model "${model_id}" "${dir}"
            printf "\n"
        fi
    done
}

function download_civitai_model() {
    local model_id="$1"
    local output_dir="$2"
    
    # First, get the model details to extract the download URL
    echo "Getting model information for ID: ${model_id}"
    
    local api_url="https://civitai.com/api/v1/models/version/${model_id}"
    local auth_header=""
    
    if [[ -n "$CIVITAI_TOKEN" ]]; then
        auth_header="--header=\"Authorization: Bearer ${CIVITAI_TOKEN}\""
    fi
    
    # Debug: Show what command we're executing
    echo "Executing API call: curl -s ${auth_header} \"${api_url}\""
    
    # Use curl to get model information
    local model_info
    if [[ -n "$CIVITAI_TOKEN" ]]; then
        model_info=$(curl -s --header "Authorization: Bearer ${CIVITAI_TOKEN}" "${api_url}")
    else
        model_info=$(curl -s "${api_url}")
    fi
    
    # Check if we got valid JSON
    if ! echo "$model_info" | jq -e . >/dev/null 2>&1; then
        echo "Error: Failed to get valid model information from Civitai"
        echo "Response: ${model_info}"
        return 1
    fi
    
    # Extract the download URL
    local download_url=$(echo "$model_info" | jq -r '.downloadUrl')
    
    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        echo "Error: Could not find download URL in model information"
        return 1
    fi
    
    # Extract the file name
    local file_name=$(echo "$model_info" | jq -r '.files[0].name')
    
    if [[ -z "$file_name" || "$file_name" == "null" ]]; then
        # Use a default file name based on the model ID
        file_name="civitai_model_${model_id}.safetensors"
    fi
    
    # Download the model
    echo "Downloading model from: ${download_url}"
    echo "Saving as: ${output_dir}/${file_name}"
    
    if [[ -n "$CIVITAI_TOKEN" ]]; then
        curl -L --header "Authorization: Bearer ${CIVITAI_TOKEN}" -o "${output_dir}/${file_name}" "${download_url}"
    else
        curl -L -o "${output_dir}/${file_name}" "${download_url}"
    fi
    
    # Check if download was successful
    if [[ $? -eq 0 ]]; then
        echo "Successfully downloaded ${file_name}"
    else
        echo "Failed to download model"
        return 1
    fi
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    local auth_header=""
    
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_header="Authorization: Bearer $HF_TOKEN"
        wget --header="$auth_header" -nc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -nc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

# Echo environment variables (safe versions) for debugging
echo "CIVITAI_TOKEN is set: $(if [[ -n "$CIVITAI_TOKEN" ]]; then echo "YES"; else echo "NO"; fi)"
echo "HF_TOKEN is set: $(if [[ -n "$HF_TOKEN" ]]; then echo "YES"; else echo "NO"; fi)"

provisioning_start