function gr --description "cd to git repository root"
    set root (git rev-parse --show-toplevel 2>/dev/null)
    or begin
        echo "Not a git repository"
        return 1
    end
    cd $root
end
