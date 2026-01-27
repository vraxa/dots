for app in $(flatpak list --columns=application); do
    branch=$(flatpak info $app --system --show-commit | awk '{print "stable"}') # Assuming stable branch
    flatpak make-current --system $app $branch
done
