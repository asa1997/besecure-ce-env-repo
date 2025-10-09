#!/bin/bash

function __besman_install {

    # Checks if GitHub CLI is present or not.
    __besman_check_vcs_exist || return 1

    # checks whether the user github id has been populated or not under BESMAN_USER_NAMESPACE
    __besman_check_github_id || return 1

    # Check if Node.js is installed, if not install it
    if [[ -z $(which node) ]]; then
        __besman_echo_white "Node.js is not installed. Installing Node.js..."
        
        # Install Node.js using NodeSource repository
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        
        [[ -z $(which node) ]] && __besman_echo_red "Node.js installation failed" && return 1
        __besman_echo_green "Node.js installed successfully"
    else
        __besman_echo_white "Node.js is already installed: $(node --version)"
    fi

    # Check if npm is available
    if [[ -z $(which npm) ]]; then
        __besman_echo_red "npm is not available. Please ensure Node.js is properly installed."
        return 1
    fi

    # Check if python3 is installed if not install it.
    if [[ -z $(which python3) ]]; then
        __besman_echo_white "Python3 is not installed. Installing python3..."
        sudo apt-get update
        sudo apt-get install python3 -y
        [[ -z $(which python3) ]] && __besman_echo_red "Python3 installation failed" && return 1
    fi

    if [[ -z $(which pip) ]]; then
        __besman_echo_white "Installing pip"
        sudo apt install python3-pip -y
        [[ -z $(which pip) ]] && __besman_echo_red "pip installation failed" && return 1
    fi

    # Ensure ~/.local/bin is in PATH
    if ! echo $PATH | grep -q "$HOME/.local/bin"; then
        __besman_echo_no_colour "Adding $HOME/.local/bin to PATH var"
        echo 'export PATH=$PATH:$HOME/.local/bin' >>~/.bashrc
        echo 'export BESMAN_DIR="$HOME/.besman"' >>~/.bashrc
        echo '[[ -s "$HOME/.besman/bin/besman-init.sh" ]] && source "$HOME/.besman/bin/besman-init.sh"' >>~/.bashrc
        source ~/.bashrc
    fi

    # Create assessment datastore directory
    if [[ -d $BESMAN_ASSESSMENT_DATASTORE_DIR ]]; then

        __besman_echo_white "Assessment datastore found at $BESMAN_ASSESSMENT_DATASTORE_DIR"
    else
        __besman_echo_white "Cloning assessment datastore from $BESMAN_USER_NAMESPACE/besecure-assessment-datastore"
        __besman_repo_clone "$BESMAN_USER_NAMESPACE" "besecure-assessment-datastore" "$BESMAN_ASSESSMENT_DATASTORE_DIR" || return 1

    fi


    # Install promptfoo globally
    __besman_echo_white "Installing promptfoo..."
    npm install -g promptfoo
    [[ $? -ne 0 ]] && __besman_echo_red "Failed to install promptfoo" && return 1
    __besman_echo_green "promptfoo installed successfully"

    # Verify promptfoo installation
    if [[ -z $(which promptfoo) ]]; then
        __besman_echo_red "promptfoo command not found in PATH"
        return 1
    fi

    # Create assessment directory structure
    mkdir -p "$HOME/agent-redteam"
    mkdir -p "$HOME/agent-redteam/configs"
    mkdir -p "$HOME/agent-redteam/results"

    # Create default promptfoo configuration file
    __besman_echo_white "Creating default promptfoo configuration..."
    
    # Create configuration based on deployment type
    if [[ "$BESMAN_AGENT_DEPLOYMENT_TYPE" == "api" ]]; then
        cat > "$HOME/agent-redteam/configs/promptfooconfig.yaml" << 'EOF'
description: <AGENT_NAME> # Replace with your agent name
targets:
  - id: http
    label: <AGENT_LABEL> # Replace with descriptive label for your agent
    config:
      url: <API_ENDPOINT_URL> # Replace with your API endpoint URL (e.g., https://your-domain.com/api/call)
      method: <HTTP_METHOD> # Replace with HTTP method (GET, POST, PUT, etc.)
      headers:
        Content-Type: <CONTENT_TYPE> # Replace with content type (e.g., application/json)
        Authorization: <AUTHORIZATION_HEADER> # Replace with auth header if needed, or remove this line
        # Add any additional headers as needed
      body: <REQUEST_BODY> # Replace with request body template (e.g., "{\"message\":\"{{prompt}}\"}")
    delay: <REQUEST_DELAY> # Adjust delay between requests as needed (e.g., 500)
prompts:
  - '{{ prompt }}'
redteam:
  purpose: |-
    Application Purpose:
    ```
    <DESCRIBE_YOUR_APPLICATION_PURPOSE>
    Replace this section with a detailed description of what your AI agent/application does,
    its main functionality, and how users interact with it.
    ```

    Industry/Domain:
    ```
    <YOUR_INDUSTRY_DOMAIN>
    Replace with your specific industry (e.g., Healthcare, Finance, Education, etc.)
    ```

    System Rules and Constraints for Attackers:
    ```
    <SYSTEM_RULES_AND_CONSTRAINTS>
    Replace this section with specific rules, constraints, and operational boundaries
    of your AI agent system that attackers should be aware of. Include:
    - What actions the agent can perform
    - Data it has access to
    - Input/output formats
    - Security measures in place
    - User interaction patterns
    ```
    Red Team User Persona:
    ```
    <RED_TEAM_PERSONA>
    Replace with a specific red team persona description. Define:
    - Who the attacker is (security researcher, malicious actor, etc.)
    - What their goals are
    - What types of failures/vulnerabilities they should target
    - Industry-specific attack scenarios to focus on
    ```


  plugins:
    - id: ascii-smuggling  # Tests vulnerability to Unicode tag-based instruction smuggling attacks
    - id: beavertails  # Tests handling of malicious prompts from the BeaverTails dataset
    - id: bias:age  # Age-related bias detection
    - id: bias:disability  # Disability-related bias detection
    - id: bias:gender  # Gender-related bias detection
    - id: bias:race  # Race-related bias detection
    - id: contracts  # Tests for unauthorized contractual commitments and legal exposure
    - id: cyberseceval  # Tests prompt injection attacks from Meta's CyberSecEval dataset
    - id: donotanswer  # Tests for vulnerabilities to Do Not Answer attacks
    - id: divergent-repetition  # Tests for training data leaks through repetitive pattern exploitation that causes model divergence
    - id: excessive-agency  # Tests for unauthorized actions beyond defined system boundaries
    - id: hallucination  # Tests for fabrication of false or misleading information
    - id: harmful:chemical-biological-weapons  # Tests handling of WMD-related content
    - id: harmful:child-exploitation  # Tests handling of child exploitation content
    - id: harmful:copyright-violations  # Tests handling of intellectual property violations
    - id: harmful:cybercrime  # Tests handling of cybercrime-related content
    - id: harmful:cybercrime:malicious-code  # Tests creation of malicious code
    - id: harmful:graphic-content  # Tests handling of graphic or violent content
    - id: harmful:harassment-bullying  # Tests handling of harassment and bullying content
    - id: harmful:hate  # Tests handling of hate speech and discriminatory content
    - id: harmful:illegal-activities  # Tests handling of general illegal activities
    - id: harmful:illegal-drugs  # Tests handling of illegal drug-related content
    - id: harmful:illegal-drugs:meth  # Tests handling of methamphetamine-related content
    - id: harmful:indiscriminate-weapons  # Tests handling of weapons-related content
    - id: harmful:insults  # Tests handling of personal attacks and insults
    - id: harmful:intellectual-property  # Tests handling of IP theft and violations
    - id: harmful:misinformation-disinformation  # Tests handling of false information campaigns
    - id: harmful:non-violent-crime  # Tests handling of non-violent criminal content
    - id: harmful:profanity  # Tests handling of profane or inappropriate language
    - id: harmful:radicalization  # Tests handling of extremist content and recruitment
    - id: harmful:self-harm  # Tests handling of self-harm and suicide content
    - id: harmful:sex-crime  # Tests handling of sexual crime content
    - id: harmful:sexual-content  # Tests handling of explicit sexual content
    - id: harmful:specialized-advice  # Tests handling of unauthorized professional advice
    - id: harmful:unsafe-practices  # Tests handling of dangerous activity instructions
    - id: harmful:violent-crime  # Tests handling of violent crime content
    - id: harmful:weapons:ied  # Tests handling of Improvised Explosive Devices
    - id: hijacking  # Tests for unauthorized resource usage and purpose deviation
    - id: imitation  # Tests handling of unauthorized impersonation of entities
    - id: overreliance  # Tests for overreliance on system assumptions
    - id: pii:direct  # Tests for direct PII exposure vulnerabilities
    - id: pliny  # Tests handling of Pliny prompt injections
    - id: politics  # Tests handling of political content and bias
    - id: religion  # Tests handling of religious content and bias
    - id: pii:api-db  # Tests for PII exposure via API/database access
    - id: pii:session  # Tests for PII exposure in session data
    - id: pii:social  # Tests for PII exposure via social engineering
    - id: prompt-extraction  # Tests for system prompt disclosure vulnerabilities
    - id: harmful:privacy  # Tests handling of privacy violation attempts
    - id: rbac  # Tests role-based access control implementation
    - id: bfla  # Tests for broken function-level authorization vulnerabilities (OWASP API 5)
    - id: bola  # Tests for broken object-level authorization vulnerabilities (OWASP API 1)
    - id: shell-injection  # Tests for command injection vulnerabilities
#    - id: sql-injection  # Tests for SQL injection vulnerabilities
    - id: ssrf  # Tests for server-side request forgery vulnerabilities
    - id: debug-access  # Tests for exposed debugging interfaces and commands
    - id: tool-discovery  # Tests for enumeration of available tools and function calls
#    - id: indirect-prompt-injection  # Tests for injection vulnerabilities via untrusted variables
    - id: competitors  # Tests for unauthorized competitor mentions and endorsements
  
  testGenerationInstructions: <TEST_GENERATION_INSTRUCTIONS>
  # Replace with domain-specific instructions for test generation. Examples:
  # - Use realistic [industry] scenarios and terminology in your prompts
  # - Vary your attack patterns to include both direct and indirect approaches
  # - Focus on [specific compliance requirements] violations
  # - Document the agent's responses and note any unexpected behaviors

  strategies:
    - id: basic  # Original plugin tests without any additional strategies or optimizations
    - id: jailbreak:composite  # Combines multiple jailbreak techniques for enhanced effectiveness
    - id: jailbreak:likert  # Uses Likert scale-based prompts to bypass content filters
    - id: jailbreak:tree  # Tree-based search for optimal safety bypass vectors
    - id: goat  # Dynamic multi-turn attack generation using adversarial techniques
      config:
        stateful: false
  numTests: <NUM_TESTS> # Replace with desired number of tests (e.g., 10, 50, 100)
  maxConcurrency: <MAX_CONCURRENCY> # Replace with desired concurrency level (e.g., 5, 10, 20)
defaultTest:
  vars: {}
  options:
    transformVars: '{ ...vars, sessionId: context.uuid }'
EOF
    else
        cat > "$HOME/agent-redteam/configs/promptfooconfig.yaml" << 'EOF'
description: <AGENT_NAME> # Replace with your agent name
targets:
  - id: <TARGET_ID> # Replace with your target (e.g., file://./agent.py:call_api, openai:gpt-4)
    label: <AGENT_LABEL> # Replace with descriptive label for your agent
    config:
      verbose: true
      # Add any additional config parameters here (API keys, model settings, etc.)
    delay: <REQUEST_DELAY> # Adjust delay between requests as needed (e.g., 500)
prompts:
  - '{{ prompt }}'
redteam:
  purpose: |-
    Application Purpose:
    ```
    <DESCRIBE_YOUR_APPLICATION_PURPOSE>
    Replace this section with a detailed description of what your AI agent/application does,
    its main functionality, and how users interact with it.
    ```

    Industry/Domain:
    ```
    <YOUR_INDUSTRY_DOMAIN>
    Replace with your specific industry (e.g., Healthcare, Finance, Education, etc.)
    ```

    System Rules and Constraints for Attackers:
    ```
    <SYSTEM_RULES_AND_CONSTRAINTS>
    Replace this section with specific rules, constraints, and operational boundaries
    of your AI agent system that attackers should be aware of. Include:
    - What actions the agent can perform
    - Data it has access to
    - Input/output formats
    - Security measures in place
    - User interaction patterns
    ```
    Red Team User Persona:
    ```
    <RED_TEAM_PERSONA>
    Replace with a specific red team persona description. Define:
    - Who the attacker is (security researcher, malicious actor, etc.)
    - What their goals are
    - What types of failures/vulnerabilities they should target
    - Industry-specific attack scenarios to focus on
    ```


  plugins:
    - id: ascii-smuggling  # Tests vulnerability to Unicode tag-based instruction smuggling attacks
    - id: beavertails  # Tests handling of malicious prompts from the BeaverTails dataset
    - id: bias:age  # Age-related bias detection
    - id: bias:disability  # Disability-related bias detection
    - id: bias:gender  # Gender-related bias detection
    - id: bias:race  # Race-related bias detection
    - id: contracts  # Tests for unauthorized contractual commitments and legal exposure
    - id: cyberseceval  # Tests prompt injection attacks from Meta's CyberSecEval dataset
    - id: donotanswer  # Tests for vulnerabilities to Do Not Answer attacks
    - id: divergent-repetition  # Tests for training data leaks through repetitive pattern exploitation that causes model divergence
    - id: excessive-agency  # Tests for unauthorized actions beyond defined system boundaries
    - id: hallucination  # Tests for fabrication of false or misleading information
    - id: harmful:chemical-biological-weapons  # Tests handling of WMD-related content
    - id: harmful:child-exploitation  # Tests handling of child exploitation content
    - id: harmful:copyright-violations  # Tests handling of intellectual property violations
    - id: harmful:cybercrime  # Tests handling of cybercrime-related content
    - id: harmful:cybercrime:malicious-code  # Tests creation of malicious code
    - id: harmful:graphic-content  # Tests handling of graphic or violent content
    - id: harmful:harassment-bullying  # Tests handling of harassment and bullying content
    - id: harmful:hate  # Tests handling of hate speech and discriminatory content
    - id: harmful:illegal-activities  # Tests handling of general illegal activities
    - id: harmful:illegal-drugs  # Tests handling of illegal drug-related content
    - id: harmful:illegal-drugs:meth  # Tests handling of methamphetamine-related content
    - id: harmful:indiscriminate-weapons  # Tests handling of weapons-related content
    - id: harmful:insults  # Tests handling of personal attacks and insults
    - id: harmful:intellectual-property  # Tests handling of IP theft and violations
    - id: harmful:misinformation-disinformation  # Tests handling of false information campaigns
    - id: harmful:non-violent-crime  # Tests handling of non-violent criminal content
    - id: harmful:profanity  # Tests handling of profane or inappropriate language
    - id: harmful:radicalization  # Tests handling of extremist content and recruitment
    - id: harmful:self-harm  # Tests handling of self-harm and suicide content
    - id: harmful:sex-crime  # Tests handling of sexual crime content
    - id: harmful:sexual-content  # Tests handling of explicit sexual content
    - id: harmful:specialized-advice  # Tests handling of unauthorized professional advice
    - id: harmful:unsafe-practices  # Tests handling of dangerous activity instructions
    - id: harmful:violent-crime  # Tests handling of violent crime content
    - id: harmful:weapons:ied  # Tests handling of Improvised Explosive Devices
    - id: hijacking  # Tests for unauthorized resource usage and purpose deviation
    - id: imitation  # Tests handling of unauthorized impersonation of entities
    - id: overreliance  # Tests for overreliance on system assumptions
    - id: pii:direct  # Tests for direct PII exposure vulnerabilities
    - id: pliny  # Tests handling of Pliny prompt injections
    - id: politics  # Tests handling of political content and bias
    - id: religion  # Tests handling of religious content and bias
    - id: pii:api-db  # Tests for PII exposure via API/database access
    - id: pii:session  # Tests for PII exposure in session data
    - id: pii:social  # Tests for PII exposure via social engineering
    - id: prompt-extraction  # Tests for system prompt disclosure vulnerabilities
    - id: harmful:privacy  # Tests handling of privacy violation attempts
    - id: rbac  # Tests role-based access control implementation
    - id: bfla  # Tests for broken function-level authorization vulnerabilities (OWASP API 5)
    - id: bola  # Tests for broken object-level authorization vulnerabilities (OWASP API 1)
    - id: shell-injection  # Tests for command injection vulnerabilities
#    - id: sql-injection  # Tests for SQL injection vulnerabilities
    - id: ssrf  # Tests for server-side request forgery vulnerabilities
    - id: debug-access  # Tests for exposed debugging interfaces and commands
    - id: tool-discovery  # Tests for enumeration of available tools and function calls
#    - id: indirect-prompt-injection  # Tests for injection vulnerabilities via untrusted variables
    - id: competitors  # Tests for unauthorized competitor mentions and endorsements
  
  testGenerationInstructions: <TEST_GENERATION_INSTRUCTIONS>
  # Replace with domain-specific instructions for test generation. Examples:
  # - Use realistic [industry] scenarios and terminology in your prompts
  # - Vary your attack patterns to include both direct and indirect approaches
  # - Focus on [specific compliance requirements] violations
  # - Document the agent's responses and note any unexpected behaviors

  strategies:
    - id: basic  # Original plugin tests without any additional strategies or optimizations
    - id: jailbreak:composite  # Combines multiple jailbreak techniques for enhanced effectiveness
    - id: jailbreak:likert  # Uses Likert scale-based prompts to bypass content filters
    - id: jailbreak:tree  # Tree-based search for optimal safety bypass vectors
    - id: goat  # Dynamic multi-turn attack generation using adversarial techniques
      config:
        stateful: false
  numTests: <NUM_TESTS> # Replace with desired number of tests (e.g., 10, 50, 100)
  maxConcurrency: <MAX_CONCURRENCY> # Replace with desired concurrency level (e.g., 5, 10, 20)
defaultTest:
  vars: {}
  options:
    transformVars: '{ ...vars, sessionId: context.uuid }'
EOF
    fi

    [[ $? -ne 0 ]] && __besman_echo_red "Failed to create promptfoo configuration" && return 1

    __besman_echo_no_colour ""
    __besman_echo_green "Agent red teaming environment installed successfully!"
    __besman_echo_no_colour ""
    
    __besman_echo_yellow "Configuration and Scripts:"
    __besman_echo_no_colour "----------------------------------------------"
    __besman_echo_white "Config file: $HOME/agent-redteam/configs/promptfooconfig.yaml"
    __besman_echo_white "Results: $HOME/agent-redteam/results/"
    __besman_echo_no_colour ""
    
    __besman_echo_yellow "Red Team Assessment Commands:"
    __besman_echo_no_colour "----------------------------------------------"
    __besman_echo_white "Run assessment with config file:"
    __besman_echo_white "  cd $HOME/agent-redteam && promptfoo redteam run --config ./configs/promptfooconfig.yaml --output ./results"
    __besman_echo_no_colour ""
    __besman_echo_white "View results:"
    __besman_echo_white "  promptfoo view"
    __besman_echo_no_colour ""

}

function __besman_uninstall {
    __besman_echo_white "Uninstalling promptfoo red teaming environment..."
    
    # Uninstall promptfoo globally
    npm uninstall -g promptfoo
    [[ $? -ne 0 ]] && __besman_echo_yellow "Warning: Failed to uninstall promptfoo globally"
    
    # Backup results before removing directories
    if [[ -d "$HOME/agent-redteam/results" ]] && [[ "$(ls -A "$HOME/agent-redteam/results")" ]]; then
        __besman_echo_white "Backing up assessment results..."
        mkdir -p "$HOME/agent-redteam-backup"
        cp -r "$HOME/agent-redteam/results"/* "$HOME/agent-redteam-backup/" 2>/dev/null
        __besman_echo_white "Results backed up to: $HOME/agent-redteam-backup/"
    fi
    
    # Remove agent-redteam directory
    if [[ -d "$HOME/agent-redteam" ]]; then
        __besman_echo_white "Removing agent-redteam directory..."
        rm -rf "$HOME/agent-redteam"
    fi
    
    __besman_echo_green "Promptfoo red teaming environment uninstalled successfully"
    __besman_echo_white "Note: Assessment results have been preserved in backup location"
    __besman_echo_no_colour ""
}

function __besman_update {
    __besman_echo_white "Updating promptfoo red teaming environment..."
    
    # Update promptfoo
    npm update -g promptfoo
    [[ $? -ne 0 ]] && __besman_echo_red "Failed to update promptfoo" && return 1
    
    
}

function __besman_validate {
    __besman_echo_white "Validating promptfoo red teaming environment..."
    
    # Check if promptfoo is installed
    if [[ -z $(which promptfoo) ]]; then
        __besman_echo_red "promptfoo is not installed or not in PATH"
        return 1
    fi
    
    # Check promptfoo version
    __besman_echo_white "Promptfoo version: $(promptfoo --version)"
    
    # Check if Node.js is available
    if [[ -z $(which node) ]]; then
        __besman_echo_red "Node.js is not installed"
        return 1
    fi
    
    __besman_echo_white "Node.js version: $(node --version)"
    
}


function __besman_reset {
    __besman_uninstall
    __besman_install
}