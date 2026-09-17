$files = Get-ChildItem -Path "game" -Filter "*.gd" -Recurse

foreach ($f in $files) {
    $content = Get-Content -Path $f.FullName -Raw
    
    # Remove ServiceLocator.register(...)
    $content = $content -replace '(?m)^\s*ServiceLocator\.register\(.*$', ''
    
    # Replace globals
    $content = $content.Replace("Logger.", "GameService.logger.")
    $content = $content.Replace("GameBus.", "GameService.bus.")
    $content = $content.Replace("GameConfig.", "GameService.config.")
    
    # Replace ServiceLocator.get_service
    $content = $content.Replace("ServiceLocator.get_service(&`"AudioManager`")", "GameService.audio")
    $content = $content.Replace("ServiceLocator.get_service(&`"GameManager`")", "GameService.game")
    $content = $content.Replace("ServiceLocator.get_service(&`"HapticsManager`")", "GameService.haptics")
    $content = $content.Replace("ServiceLocator.get_service(&`"NetworkManager`")", "GameService.network")
    $content = $content.Replace("ServiceLocator.get_service(&`"SaveManager`")", "GameService.save")
    $content = $content.Replace("ServiceLocator.get_service(&`"SceneManager`")", "GameService.scene")
    $content = $content.Replace("ServiceLocator.get_service(&`"UIManager`")", "GameService.ui")
    
    # Clean up any leftover empty _ready functions
    # (Optional, won't break if left empty)
    
    Set-Content -Path $f.FullName -Value $content -NoNewline
}
