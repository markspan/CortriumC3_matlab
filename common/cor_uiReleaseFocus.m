function cor_uiReleaseFocus(hObj)
    % Hack to bring focus back to figure window.
    % Disables a uicontrol obj, calls drawnow, and re-enables obj.
    set(hObj, 'Enable', 'off');
    drawnow;
    set(hObj, 'Enable', 'on');
end