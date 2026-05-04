local module = {}

local TweenService = game:GetService("TweenService")
local _fovTween: Tween?

function module.TweenFOV(easing: TweenInfo, targetFov: number)
	print("CameraManager: TweenFOV")
	
	if _fovTween then
		_fovTween:Cancel()
	end
	_fovTween = TweenService:Create(workspace.CurrentCamera, easing, {
		FieldOfView = targetFov
	})
	_fovTween:Play()
end

function module.ResetFOV(easing: TweenInfo?)
	if _fovTween then
		_fovTween:Cancel()
		_fovTween = nil
	end
	
	if easing then
		_fovTween = TweenService:Create(workspace.CurrentCamera, easing, {
			FieldOfView = 70
		})
		_fovTween:Play()
	else
		workspace.CurrentCamera.FieldOfView = 70
	end
	
	
end

return module
