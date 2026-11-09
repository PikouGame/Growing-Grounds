-- Native cylinder meshes are 100 cm across. Preserve their authored Z scale
-- and the slight separation between the two boundary surfaces.
return function(E)
    return function(actor,radius,force)
        for _,field in ipairs({'AreaRange','AreaRange1'}) do
            local c=actor[field]
            if E.valid(c) then
                local n=radius/50+(field=='AreaRange1' and 0.01 or 0)
                local v=c.RelativeScale3D
                if force or math.abs(v.X-n)>0.001 or math.abs(v.Y-n)>0.001 then
                    c:SetRelativeScale3D({X=n,Y=n,Z=v.Z})
                end
            end
        end
    end
end
